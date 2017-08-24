//
//  ToJSON.swift
//  SWWebView
//
//  Created by alastair.coote on 10/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

protocol ToJSON {
    func toJSONSuitableObject() -> Any
}

extension URL {
    var sWWebviewSuitableAbsoluteString: String {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        components.scheme = SWWebView.ServiceWorkerScheme
        return components.url!.absoluteString
    }

    init?(swWebViewString: String) {
        var urlComponents = URLComponents(string: swWebViewString)
        if urlComponents != nil {
            urlComponents!.scheme = urlComponents!.host == "localhost" ? "http" : "https"
        }
        if urlComponents?.url == nil {
            return nil
        } else {
            self = urlComponents!.url!
        }
    }
}
