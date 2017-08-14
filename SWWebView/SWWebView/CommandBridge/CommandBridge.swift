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
        "/serviceworkercontainer/register": ServiceWorkerContainerCommands.register
    ]
    
    static var stopRoutes: [String: (SWURLSchemeTask) -> Void] = [
        "/events": { task in EventStream.remove(for: task) },
        ]

    static func processSchemeStart(task: SWURLSchemeTask) {

        let matchingRoute = routes.first(where: { $0.key == task.request.url!.path })

        if matchingRoute == nil {
            Log.error?("SW Request sent to unrecognised URL: \(task.request.url!.absoluteString)")
            let notFound = HTTPURLResponse(url: task.request.url!, statusCode: 404, httpVersion: "1.0", headerFields: nil)!
            task.didReceive(notFound)
            task.didFinish()
            return
        }

        _ = matchingRoute!.value(task)
    }
    
    static func processSchemeStop(task: WKURLSchemeTask) {
        let matchingRoute = stopRoutes.first(where: { $0.key == task.request.url!.path })
        
        if matchingRoute == nil {
            Log.error?("Tried to stop a connection that has no route. This should never happen.")
            return
        }
        
        let modifiedTask = SWURLSchemeTask(underlyingTask: task)
        
        _ = matchingRoute!.value(modifiedTask)
    }
    
    static func processAsJSON(task: SWURLSchemeTask, _ asJSON: @escaping (AnyObject) throws -> Promise<Any>) {
        
        firstly { () -> Promise<Any> in
            let jsonBody = try JSONSerialization.jsonObject(with: task.request.httpBody!, options: [])
            return try asJSON(jsonBody as AnyObject)
        }
            .then { jsonResponse -> Void in
                
                let encodedResponse = try JSONSerialization.data(withJSONObject: jsonResponse, options: [])
                
                task.didReceive(URLResponse(url: task.request.url!, mimeType: "application/json", expectedContentLength: encodedResponse.count, textEncodingName: nil))
                
                task.didReceive(encodedResponse)
                task.didFinish()
                
                
        }
            .catch { error in
                
                do {
                    let encodedResponse = try JSONSerialization.data(withJSONObject: [
                        "error": "\(error)"
                    ], options: [])
                    
                    task.didReceive(HTTPURLResponse(url: task.request.url!, statusCode: 500, httpVersion: "1.1", headerFields: nil)!)
                    task.didReceive(encodedResponse)
                    task.didFinish()
                    
                } catch {
                    // In case we can't even report errors correctly.
                    task.didFailWithError(error)
                }
                
                
                
                
                
        }
        
    }
}
