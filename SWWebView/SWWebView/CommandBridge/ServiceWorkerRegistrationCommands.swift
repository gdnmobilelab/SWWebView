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
import PromiseKit

class ServiceWorkerRegistrationCommands {

    static func unregister(container _: ServiceWorkerContainer, json: AnyObject?) throws -> Promise<Any?>? {

        guard let registrationID = json?["id"] as? String else {
            throw ErrorMessage("Must provide registration ID in JSON body")
        }

        guard let reg = try ServiceWorkerRegistration.get(byId: registrationID) else {
            throw ErrorMessage("Registration does not exist any more")
        }

        return reg.unregister()
            .then {
                [
                    "success": true,
                ]
            }
    }
}
