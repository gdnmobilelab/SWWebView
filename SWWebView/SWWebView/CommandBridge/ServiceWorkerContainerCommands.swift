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
            
            var scope: URL? = nil
            if let scopeString = json!["scope"] as? String {
                scope = URL(string: scopeString)
                if scope == nil {
                    throw ErrorMessage("Did not understand passed in scope argument")
                }
            }
            
            
            let container = ServiceWorkerContainer.get(for: task.request.mainDocumentURL!)
            return container.getRegistration(scope)
                .then {reg in
                    return reg?.toJSONSuitableObject()
                    
            }
        }
    }
    
    static func getRegistrations(task: SWURLSchemeTask) {
        CommandBridge.processAsJSON(task: task) { json in
            let container = ServiceWorkerContainer.get(for: task.request.mainDocumentURL!)
            return container.getRegistrations()
                .then {regs in
                    return regs.map { $0.toJSONSuitableObject() }
                    
            }
        }
    }
    
    static func register(task: SWURLSchemeTask) {
        CommandBridge.processAsJSON(task: task) { json in
           
            guard let workerURLString = json!["url"] as? String else {
                throw ErrorMessage("URL must be provided")
            }
            
            guard let workerURL = URL(string: workerURLString, relativeTo: task.request.url!) else {
                throw ErrorMessage("Could not parse URL")
            }
            
            var options:ServiceWorkerRegistrationOptions? = nil
            
            if let specifiedScope = json!["scope"] as? String {
                guard let specifiedScopeURL = URL(string: specifiedScope, relativeTo: task.request.mainDocumentURL!) else {
                    throw ErrorMessage("Could not parse scope URL")
                }
                options = ServiceWorkerRegistrationOptions(scope: specifiedScopeURL)

            }
            
            let container = ServiceWorkerContainer.get(for: task.request.mainDocumentURL!)
            
            return container.register(workerURL: workerURL, options: options)
                .then { result in
                    return result.toJSONSuitableObject()
            }
        }
    }
    
}
