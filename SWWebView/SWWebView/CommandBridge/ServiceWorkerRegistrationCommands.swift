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

    static func unregister(container: ServiceWorkerContainer, json: AnyObject?) throws -> Promise<Any?>? {

        guard let registrationID = json?["id"] as? String else {
            throw ErrorMessage("Must provide registration ID in JSON body")
        }

        return container.getRegistrations()
            .then { registrations in

                guard let registration = registrations.first(where: { $0.id == registrationID }) else {
                    throw ErrorMessage("Registration does not exist")
                }

                return registration.unregister()
            }
            .then {
                [
                    "success": true,
                ]
            }
    }
}
