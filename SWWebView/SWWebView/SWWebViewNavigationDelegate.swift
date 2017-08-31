//
//  SWWebViewNavigationDelegate.swift
//  SWWebView
//
//  Created by alastair.coote on 07/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorker

class SWWebViewNavigationDelegate: NSObject, WKNavigationDelegate {

    func isServiceWorkerPermittedURL(_ webview: SWWebView, url: URL) -> Bool {

        var checkFor = url.host!
        if url.port != nil && url.port != 80 {
            checkFor += ":" + String(url.port!)
        }

        return webview.serviceWorkerPermittedDomains.contains(checkFor)
    }

    func makeServiceWorkerSuitableURLRequest(_ webview: SWWebView, request: URLRequest) -> URLRequest {

        if request.url!.scheme == SWWebView.ServiceWorkerScheme && self.isServiceWorkerPermittedURL(webview, url: request.url!) == true {
            // already the correct scheme
            return request
        } else if request.url!.scheme != SWWebView.ServiceWorkerScheme && self.isServiceWorkerPermittedURL(webview, url: request.url!) == false {
            // also correct (but non-SW) scheme
            return request
        }

        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        if webview.serviceWorkerPermittedDomains.contains(components.host!) {
            components.scheme = SWWebView.ServiceWorkerScheme
        } else {
            // no way of knowing if we want http or https here really, but for security, we'll default to
            // https
            components.scheme = "https"
        }

        var finalRequest = URLRequest(url: components.url!, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)

        finalRequest.allHTTPHeaderFields = request.allHTTPHeaderFields

        return finalRequest
    }

    func makeNonServiceWorker(url: URL) -> URL {
        if url.scheme != SWWebView.ServiceWorkerScheme {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.scheme = "https"
        return components.url!
    }

    func makeNonServiceWorker(urlRequest request: URLRequest) -> URLRequest {

        if request.url?.scheme != SWWebView.ServiceWorkerScheme {
            return request
        }

        var finalRequest = URLRequest(url: self.makeNonServiceWorker(url: request.url!), cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)

        finalRequest.allHTTPHeaderFields = request.allHTTPHeaderFields

        return finalRequest
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let swWebView = webView as? SWWebView else {
            Log.error?("Trying to use SWNavigationDelegate on a non-SWWebView class")
            return decisionHandler(.allow)
        }

        if navigationAction.request.url == nil {
            // Not sure in what circumstance this would ever happen, but safe to say
            // we don't want our handler to kick in.
            if let delegate = swWebView.navigationDelegate {
                guard delegate.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler) != nil else {
                    return decisionHandler(.allow)
                }
            } else {
                return decisionHandler(.allow)
            }
        } else if navigationAction.request.url!.scheme == SWWebView.ServiceWorkerScheme {

            // If we're already using the service worker scheme, we need to double check that
            // we're using a domain allowed by our configuration.

            if self.isServiceWorkerPermittedURL(swWebView, url: navigationAction.request.url!) {

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
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        guard let swWebView = webView as? SWWebView else {
            Log.error?("Trying to use SWNavigationDelegate on a non-SWWebView class")
            return decisionHandler(.allow)
        }

        if navigationResponse.response.url == nil || navigationResponse.response.url!.scheme != SWWebView.ServiceWorkerScheme {

            // If there is no URL(?) or the URL is not a service worker one, then we just pass it straight through.

            guard swWebView.navigationDelegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler) != nil else {
                return decisionHandler(.allow)
            }

        } else {

            // If it is a SW URL we need to manually construct a shimmed response with the correct URL, to pass
            // back out to our navigation delegate, if it exists.

            let nonSWURL = self.makeNonServiceWorker(url: navigationResponse.response.url!)

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
