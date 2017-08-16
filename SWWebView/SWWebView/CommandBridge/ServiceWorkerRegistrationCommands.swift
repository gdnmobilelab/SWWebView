//
//  ServiceWorkerRegistrationCommands.swift
//  SWWebView
//
//  Created by alastair.coote on 14/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorkerContainer
import ServiceWorker

class ServiceWorkerRegistrationCommands {
    
    static func unregister(task: SWURLSchemeTask) {
        CommandBridge.processAsJSON(task: task) { json in
            
            let registrationScope = URL(string:json!["scope"] as! String)!
            let correctedScope = SWURLConverter.toHTTP(registrationScope)
            
            let registrationID = json!["id"] as! String
            
            let reg = try ServiceWorkerRegistration.get(scope: correctedScope, id: registrationID)
            
            if reg == nil {
                throw ErrorMessage("Registration does not exist any more")
            }
            
            return reg!.unregister()
                .then {
                return [
                    "success": true
                ]
            }
        }
    }
    
}
