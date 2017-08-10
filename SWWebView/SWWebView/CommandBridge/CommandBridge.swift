//
//  CommandBridge.swift
//  SWWebView
//
//  Created by alastair.coote on 09/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorker

class CommandBridge {

    static var routes: [String: (WKURLSchemeTask, Data?) -> Void] = [
        "/events": { task, data in EventStream(for: task) },
    ]

    static func processWebview(task: WKURLSchemeTask, data: Data?) {

        let matchingRoute = routes.first(where: { $0.key == task.request.url!.path })

        if matchingRoute == nil {
            Log.error?("SW Request sent to unrecognised URL: \(task.request.url!.absoluteString)")
            let notFound = HTTPURLResponse(url: task.request.url!, statusCode: 404, httpVersion: "1.0", headerFields: nil)!
            task.didReceive(notFound)
            task.didFinish()
            return
        }

        _ = matchingRoute!.value(task, data)
    }
}
