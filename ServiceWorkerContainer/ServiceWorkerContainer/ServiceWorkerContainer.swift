//
//  ServiceWorkerContainer.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import ServiceWorker

public class ServiceWorkerContainer {

    let containerURL: URL

    init(forURL: URL) {
        self.containerURL = forURL
    }


    func register(workerURL: URL, options: ServiceWorkerRegistrationOptions?) -> Promise<ServiceWorkerRegistration> {

        return firstly {
            var scopeURL = containerURL
            if let scope = options?.scope {
                // By default we register to the current URL, but we can specify
                // another scope.
                if scopeURL.host != containerURL.host || workerURL.host != containerURL.host {
                    throw ErrorMessage("Service worker scope must be on the same domain as both the page and worker URL")
                }
                scopeURL = scope
            }

            if workerURL.absoluteString.starts(with: scopeURL.absoluteString) == false {
                throw ErrorMessage("Script must be within scope")
            }

            var registration = try ServiceWorkerRegistration.get(scope: scopeURL)
            if registration == nil {
                registration = try ServiceWorkerRegistration.create(scope: scopeURL)
            }
            return registration!.register(workerURL)
                .then {
                    registration!
                }
        }
    }
}
