//
//  SWSchemeHandler.swift
//  SWWebView
//
//  Created by alastair.coote on 08/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorker
import PromiseKit

/// This is the class that intercepts any requests sent to our SW scheme. It also
/// handles calls to the service worker API itself, which are sent as HTTP requests
class SWSchemeHandler: NSObject, WKURLSchemeHandler {

    static let serviceWorkerRequestMethod = "SW_REQUEST"
    static let serviceWorkerRequestHost = "__swwebview"
    static let graftedRequestBodyHeader = "X-Grafted-Request-Body"

    func webView(_: WKWebView, start urlSchemeTask: WKURLSchemeTask) {

        let modifiedTask = SWURLSchemeTask(underlyingTask: urlSchemeTask)
        
        if urlSchemeTask.request.httpMethod == SWSchemeHandler.serviceWorkerRequestMethod {
            CommandBridge.processSchemeStart(task: modifiedTask)
            return
        } else if urlSchemeTask.request.url!.host == SWSchemeHandler.serviceWorkerRequestHost && urlSchemeTask.request.httpMethod == "OPTIONS" && urlSchemeTask.request.url!.scheme == SWWebView.ServiceWorkerScheme {
            return CommandBridge.processOPTIONSTask(task: modifiedTask)
        }

        // Need to flesh this out, but for now we're using this for tests
        let req = FetchRequest(url: modifiedTask.request.url!)
        req.cache = .NoCache

        FetchOperation.fetch(req)
            .then { res -> Promise<Data> in

                var headerDict: [String: String] = [:]
                res.headers.keys().forEach { header in
                    headerDict[header] = res.headers.get(header)
                }

                headerDict["Cache-Control"] = "no-cache"

                try modifiedTask.didReceive(HTTPURLResponse(url: modifiedTask.originalServiceWorkerURL, statusCode: res.status, httpVersion: "1.1", headerFields: headerDict)!)
                return res.data()
            }
            .then { data -> Void in
                try modifiedTask.didReceive(data)
                try modifiedTask.didFinish()
            }
            .catch { error in
                modifiedTask.didFailWithError(error)
            }
    }

    func webView(_: WKWebView, stop task: WKURLSchemeTask) {
        NSLog("stahp: \(task.request.url!)")

        guard let modifiedTask = SWURLSchemeTask.getExistingTask(for: task) else {
            Log.error?("A task stopped that doesn't exist. This shouldn't be possible")
            return
        }
        
        modifiedTask.close()
        
        if task.request.httpMethod == SWSchemeHandler.serviceWorkerRequestMethod {
            CommandBridge.processSchemeStop(task: modifiedTask)
        }
    }
}
