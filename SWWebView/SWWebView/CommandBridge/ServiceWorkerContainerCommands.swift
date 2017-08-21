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

    static func getRegistration(task: SWURLSchemeTask) {
        CommandBridge.processAsJSON(task: task) { json in

            var scope: URL?
            if let scopeString = json!["scope"] as? String {
                scope = URL(string: scopeString)
                if scope == nil {
                    throw ErrorMessage("Did not understand passed in scope argument")
                }
            }

            let pageURL = URL(string: json!["path"] as! String, relativeTo: task.origin!)!
            
            let container = try ServiceWorkerContainer.get(for: pageURL)
            return container.getRegistration(scope)
                .then { reg in
                    reg?.toJSONSuitableObject()
                }
        }
    }

    static func getRegistrations(task: SWURLSchemeTask) {
        CommandBridge.processAsJSON(task: task) { json in
            let pageURL = URL(string: json!["path"] as! String, relativeTo: task.origin!)!
            let container = try ServiceWorkerContainer.get(for: pageURL)
            return container.getRegistrations()
                .then { regs in
                    regs.map { $0.toJSONSuitableObject() }
                }
        }
    }

    static func register(task: SWURLSchemeTask) {
        CommandBridge.processAsJSON(task: task) { json in

            let pageURL = URL(string: json!["path"] as! String, relativeTo: task.origin!)!
            
            
            guard let workerURLString = json!["url"] as? String else {
                throw ErrorMessage("URL must be provided")
            }

            guard let workerURL = URL(string: workerURLString, relativeTo: pageURL) else {
                throw ErrorMessage("Could not parse URL")
            }

            var options: ServiceWorkerRegistrationOptions?

            
            if let specifiedScope = json!["scope"] as? String {
                
                guard let specifiedScopeURL = URL(string: specifiedScope, relativeTo: pageURL) else {
                    throw ErrorMessage("Could not parse scope URL")
                }
                options = ServiceWorkerRegistrationOptions(scope: specifiedScopeURL)
            }

            let container = try ServiceWorkerContainer.get(for: pageURL)

            return container.register(workerURL: workerURL, options: options)
                .then { result in
                    result.toJSONSuitableObject()
                }
        }
    }
}
