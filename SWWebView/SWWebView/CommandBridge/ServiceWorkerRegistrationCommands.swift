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
            
            let registrationScope = json["scope"] as! String
            let scopeAsURL = URL(string: registrationScope)!
            
            let reg = try ServiceWorkerRegistration.get(scope: scopeAsURL)
            return reg!.unregister()
                .then {
                return [
                    "success": true
                ]
            }
        }
    }
    
}
