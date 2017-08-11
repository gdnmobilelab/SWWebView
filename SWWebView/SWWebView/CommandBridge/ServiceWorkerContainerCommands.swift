//
//  ServiceWorkerContainerCommands.swift
//  SWWebView
//
//  Created by alastair.coote on 10/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorkerContainer
import ServiceWorker

class ServiceWorkerContainerCommands {
    
    static func register(task: WKURLSchemeTask, data: Data?) {
        CommandBridge.processAsJSON(task: task, data: data!) { json in
           
            guard let workerURLString = json["url"] as? String else {
                throw ErrorMessage("URL must be provided")
            }
            
            guard let workerURL = URL(string: workerURLString, relativeTo: task.request.url!) else {
                throw ErrorMessage("Could not parse URL")
            }
            
            // defaults to current directory of page
            var scope = task.request.url!.deletingLastPathComponent()
            
            if let specifiedScope = json["scope"] as? String {
                guard let specifiedScopeURL = URL(string: specifiedScope, relativeTo: task.request.url!) else {
                    throw ErrorMessage("Could not parse scope URL")
                }
                scope = specifiedScopeURL
            }
            
            let container = ServiceWorkerContainer.get(for: task.request.mainDocumentURL!)
            
            let options = ServiceWorkerRegistrationOptions(scope: scope)
            
            return container.register(workerURL: workerURL, options: options)
                .then { result in
                    return result.toJSONSuitableObject()
            }
        }
    }
    
}
