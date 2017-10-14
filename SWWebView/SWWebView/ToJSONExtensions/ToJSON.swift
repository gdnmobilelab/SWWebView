import Foundation

protocol ToJSON {
    func toJSONSuitableObject() -> Any
}

extension URL {
    var sWWebviewSuitableAbsoluteString: String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.scheme = SWWebView.ServiceWorkerScheme

        return components.url?.absoluteString ?? nil
    }

    init?(swWebViewString: String) {
        guard var urlComponents = URLComponents(string: swWebViewString) else {
            return nil
        }

        urlComponents.scheme = urlComponents.host == "localhost" ? "http" : "https"

        if let url = urlComponents.url {
            self = url
        } else {
            return nil
        }
    }
}
