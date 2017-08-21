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

         let registrationID = json!["id"] as! String
           
            let reg = try ServiceWorkerRegistration.get(byId: registrationID)

            if reg == nil {
                throw ErrorMessage("Registration does not exist any more")
            }

            return reg!.unregister()
                .then {
                    [
                        "success": true,
                    ]
                }
        }
    }
}
