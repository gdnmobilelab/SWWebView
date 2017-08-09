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
class SWSchemeHandler : NSObject, WKURLSchemeHandler {
    
    static let serviceWorkerRequestMethod = "SW_REQUEST"
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        
        if urlSchemeTask.request.httpMethod == SWSchemeHandler.serviceWorkerRequestMethod {
            CommandBridge.processWebview(task: urlSchemeTask)
        }
        
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        
    }
    
}
