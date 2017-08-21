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
import PromiseKit

public class CommandBridge {

    public static var routes: [String: (SWURLSchemeTask) -> Void] = [
        "/events": { task in EventStream.create(for: task) },
        "/ServiceWorkerContainer/register": ServiceWorkerContainerCommands.register,
        "/ServiceWorkerContainer/getregistration": ServiceWorkerContainerCommands.getRegistration,
        "/ServiceWorkerContainer/getregistrations": ServiceWorkerContainerCommands.getRegistrations,
        "/ServiceWorkerRegistration/unregister": ServiceWorkerRegistrationCommands.unregister,
    ]

    static var stopRoutes: [String: (SWURLSchemeTask) -> Void] = [
        "/events": { task in EventStream.remove(for: task) },
    ]

    static func processSchemeStart(task: SWURLSchemeTask) {
        
        if task.request.url!.host != SWSchemeHandler.serviceWorkerRequestHost {
            return self.send404(for:task)
        }

        let matchingRoute = routes.first(where: { $0.key == task.request.url!.path })

        if matchingRoute == nil {
            Log.error?("SW Request sent to unrecognised URL: \(task.request.url!.absoluteString)")
            return self.send404(for: task)
        }

        _ = matchingRoute!.value(task)
    }

    static func processSchemeStop(task: SWURLSchemeTask) {
        let matchingRoute = stopRoutes.first(where: { $0.key == task.request.url!.path })

        if matchingRoute == nil {
            Log.error?("Tried to stop a connection that has no route. This should never happen.")
            return
        }

        _ = matchingRoute!.value(task)
    }
    
    
    /// Since these are real HTTP requests being sent, the browser insists on sending an OPTIONS
    /// request before the actual SW_REQUEST. So we need to make sure we reply with the correct
    /// CORS headers.
    static func processOPTIONSTask(task: SWURLSchemeTask) {
        let response = HTTPURLResponse(url: task.originalServiceWorkerURL, statusCode: 200, httpVersion: nil, headerFields: [
            "Access-Control-Allow-Methods": SWSchemeHandler.serviceWorkerRequestMethod,
            "Access-Control-Allow-Origin": task.request.value(forHTTPHeaderField: "Origin")!,
            "Access-Control-Allow-Headers": "content-type, origin, X-Grafted-Request-Body"
            ])
        do {
            try task.didReceive(response!)
            try task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }
    
    fileprivate static func send404(for task: SWURLSchemeTask) {
        do {
            let notFound = HTTPURLResponse(url: task.request.url!, statusCode: 404, httpVersion: nil, headerFields: [
            "Access-Control-Allow-Origin": task.request.value(forHTTPHeaderField: "origin")!
            ])!
        try task.didReceive(notFound)
        try task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    static func processAsJSON(task: SWURLSchemeTask, _ asJSON: @escaping (AnyObject?) throws -> Promise<Any?>) {

        firstly { () -> Promise<Any?> in
            var jsonBody: AnyObject?
            if let body = task.request.httpBody {
                jsonBody = try JSONSerialization.jsonObject(with: body, options: []) as AnyObject
            }

            return try asJSON(jsonBody as AnyObject)
        }
        .then { jsonResponse -> Void in

            var encodedResponse = "null".data(using: .utf8)!
            if let response = jsonResponse {
                encodedResponse = try JSONSerialization.data(withJSONObject: response, options: [])
            }

            try task.didReceive(HTTPURLResponse(url: task.originalServiceWorkerURL, statusCode: 200, httpVersion: nil, headerFields: [
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": task.origin!.sWWebviewSuitableAbsoluteString
            ])!)

            try task.didReceive(encodedResponse)
            try task.didFinish()
        }
        .catch { error in

            do {
                let encodedResponse = try JSONSerialization.data(withJSONObject: [
                    "error": "\(error)",
                ], options: [])

                try task.didReceive(HTTPURLResponse(url: task.request.url!, statusCode: 500, httpVersion: "1.1", headerFields: [
                        "Access-Control-Allow-Origin": task.origin!.sWWebviewSuitableAbsoluteString
                    ])!)
                try task.didReceive(encodedResponse)
                try task.didFinish()

            } catch {
                // In case we can't even report errors correctly.
                task.didFailWithError(error)
            }
        }
    }
}
