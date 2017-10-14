import Foundation
import WebKit
import ServiceWorker

class SWWebViewNavigationDelegate: NSObject, WKNavigationDelegate {

    func isServiceWorkerPermittedURL(_ webview: SWWebView, url: URL) -> Bool {

        guard let host = url.host else {
            return false
        }

        var checkFor = host

        if let port = url.port, url.port != 80 {
            checkFor += ":" + String(port)
        }

        return webview.serviceWorkerPermittedDomains.contains(checkFor)
    }

    func makeServiceWorkerSuitableURLRequest(_ webview: SWWebView, request: URLRequest) -> URLRequest {

        guard let url = request.url else {
            // If there is no URL there is nothing to do here
            return request
        }

        if url.scheme == SWWebView.ServiceWorkerScheme && self.isServiceWorkerPermittedURL(webview, url: url) == true {
            // already the correct scheme
            return request
        } else if url.scheme != SWWebView.ServiceWorkerScheme && self.isServiceWorkerPermittedURL(webview, url: url) == false {
            // also correct (but non-SW) scheme
            return request
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            Log.error?("Could not convert requested URL to components")
            return request
        }

        guard let host = components.host else {
            // If we have no host then nothing to do here
            return request
        }

        if webview.serviceWorkerPermittedDomains.contains(host) {
            components.scheme = SWWebView.ServiceWorkerScheme
        } else {
            // no way of knowing if we want http or https here really, but for security, we'll default to
            // https
            components.scheme = "https"
        }

        guard let recreatedURL = components.url else {
            Log.error?("Could not transform worker-suitable URL back to a URL instance")
            return request
        }

        var finalRequest = URLRequest(url: recreatedURL, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)

        finalRequest.allHTTPHeaderFields = request.allHTTPHeaderFields

        return finalRequest
    }

    func makeNonServiceWorker(url: URL) -> URL {
        if url.scheme != SWWebView.ServiceWorkerScheme {
            return url
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = "https"

        guard let transformedURL = components.url else {
            Log.error?("Could not return recombined URL for non-SW URL")
            return url
        }
        return transformedURL
    }

    func makeNonServiceWorker(urlRequest request: URLRequest) -> URLRequest {

        if request.url?.scheme != SWWebView.ServiceWorkerScheme {
            return request
        }

        guard let url = request.url else {
            // No URL, so nothing to do
            return request
        }

        var finalRequest = URLRequest(url: self.makeNonServiceWorker(url: url), cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)

        finalRequest.allHTTPHeaderFields = request.allHTTPHeaderFields

        return finalRequest
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let swWebView = webView as? SWWebView else {
            Log.error?("Trying to use SWNavigationDelegate on a non-SWWebView class")
            return decisionHandler(.allow)
        }

        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }

        if url.scheme == SWWebView.ServiceWorkerScheme {
            // If we're already using the service worker scheme, we need to double check that
            // we're using a domain allowed by our configuration.

            if self.isServiceWorkerPermittedURL(swWebView, url: url) {

                // It's a permitted domain, but if we have a navigation delegate we want to forward
                // the (non-SW) URL to that to see if we should continue.

                if let delegate = swWebView.navigationDelegate {

                    let nonSWRequest = self.makeNonServiceWorker(urlRequest: navigationAction.request)

                    let nonSWAction = SWNavigationAction(request: nonSWRequest, sourceFrame: navigationAction.sourceFrame, targetFrame: navigationAction.targetFrame, navigationType: navigationAction.navigationType)

                    // The delegate methods are optional, so if they aren't specified, we allow by default.
                    guard delegate.webView?(webView, decidePolicyFor: nonSWAction, decisionHandler: decisionHandler) != nil else {
                        decisionHandler(.allow)
                        return
                    }
                }

                decisionHandler(.allow)
                return

            } else {

                // If it is not a permitted domain, we disallow the navigation, then immediately forward
                // the webview to a URL without the SW scheme
                decisionHandler(.cancel)

                _ = swWebView.load(self.makeServiceWorkerSuitableURLRequest(swWebView, request: navigationAction.request))

                return
            }
        } else {
            // Not sure in what circumstance this would ever happen, but safe to say
            // we don't want our handler to kick in.
            if let delegate = swWebView.navigationDelegate {
                guard delegate.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler) != nil else {
                    return decisionHandler(.allow)
                }
            } else {
                return decisionHandler(.allow)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        guard let swWebView = webView as? SWWebView else {
            Log.error?("Trying to use SWNavigationDelegate on a non-SWWebView class")
            return decisionHandler(.allow)
        }

        guard let url = navigationResponse.response.url else {
            return decisionHandler(.allow)
        }

        if url.scheme != SWWebView.ServiceWorkerScheme {

            // If the URL is not a service worker one, then we just pass it straight through.

            guard swWebView.navigationDelegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler) != nil else {
                return decisionHandler(.allow)
            }

        } else {

            // If it is a SW URL we need to manually construct a shimmed response with the correct URL, to pass
            // back out to our navigation delegate, if it exists.

            let nonSWURL = self.makeNonServiceWorker(url: url)

            let response = URLResponse(url: nonSWURL, mimeType: navigationResponse.response.mimeType, expectedContentLength: Int(navigationResponse.response.expectedContentLength), textEncodingName: navigationResponse.response.textEncodingName)

            let nonSWNavResponse = SWNavigationResponse(response: response, isForMainFrame: navigationResponse.isForMainFrame, canShowMIMEType: navigationResponse.canShowMIMEType)

            guard swWebView.navigationDelegate?.webView?(webView, decidePolicyFor: nonSWNavResponse, decisionHandler: decisionHandler) != nil else {

                // If there is no delegate, or it doesn't implement this method, we just allow it.

                decisionHandler(.allow)
                return
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        webView.navigationDelegate?.webView?(webView, didCommit: navigation)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        webView.navigationDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        webView.navigationDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.navigationDelegate?.webView?(webView, didFail: navigation, withError: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.navigationDelegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.navigationDelegate?.webView?(webView, didFinish: navigation)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.navigationDelegate?.webViewWebContentProcessDidTerminate?(webView)
    }
}
