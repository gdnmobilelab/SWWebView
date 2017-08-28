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
import PromiseKit

class ServiceWorkerContainerCommands {

    static func getRegistration(container: ServiceWorkerContainer, json: AnyObject?) throws -> Promise<Any?>? {

        var scope: URL?
        if let scopeString = json?["scope"] as? String {

            guard let specifiedScope = URL(string: scopeString) else {
                throw ErrorMessage("Did not understand passed in scope argument")
            }

            scope = specifiedScope
        }

        return container.getRegistration(scope)
            .then { reg in
                reg?.toJSONSuitableObject()
            }
    }

    static func getRegistrations(container: ServiceWorkerContainer, json _: AnyObject?) throws -> Promise<Any?>? {
        return container.getRegistrations()
            .then { regs in
                regs.map { $0.toJSONSuitableObject() }
            }
    }

    static func register(container: ServiceWorkerContainer, json: AnyObject?) throws -> Promise<Any?>? {

        guard let workerURLString = json?["url"] as? String else {
            throw ErrorMessage("URL must be provided")
        }

        guard let workerURL = URL(string: workerURLString, relativeTo: container.url) else {
            throw ErrorMessage("Could not parse URL")
        }

        var options: ServiceWorkerRegistrationOptions?

        if let specifiedScope = json?["scope"] as? String {

            guard let specifiedScopeURL = URL(string: specifiedScope, relativeTo: container.url) else {
                throw ErrorMessage("Could not parse scope URL")
            }
            options = ServiceWorkerRegistrationOptions(scope: specifiedScopeURL)
        }

        return container.register(workerURL: workerURL, options: options)
            .then { result in
                result.toJSONSuitableObject()
            }
    }
}
