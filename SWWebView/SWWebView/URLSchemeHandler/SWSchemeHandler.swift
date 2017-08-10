//
//  SWSchemeHandler.swift
//  SWWebView
//
//  Created by alastair.coote on 08/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit

/// This is the class that intercepts any requests sent to our SW scheme. It also
/// handles calls to the service worker API itself, which are sent as HTTP requests
class SWSchemeHandler: NSObject, WKURLSchemeHandler {

    static let serviceWorkerRequestMethod = "SW_REQUEST"
    static let graftedRequestBodyHeader = "X-Grafted-Request-Body"

    func webView(_: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    
        // Because WKURLSchemeTask doesn't receive POST bodies (rdar://33814386) we have to
        // graft them into a header. Gross. Hopefully this gets fixed.
        
        let graftedBody = urlSchemeTask.request.value(forHTTPHeaderField: SWSchemeHandler.graftedRequestBodyHeader)
        var data:Data? = nil
        
        if let body = graftedBody {
            data = body.data(using: String.Encoding.utf8)
        }
        
        
        if urlSchemeTask.request.httpMethod == SWSchemeHandler.serviceWorkerRequestMethod {
            CommandBridge.processWebview(task: urlSchemeTask, data: data)
        }
    }

    func webView(_: WKWebView, stop _: WKURLSchemeTask) {
    }
}
