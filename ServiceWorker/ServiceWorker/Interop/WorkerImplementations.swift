//
//  WorkerImplementations.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public class WorkerImplementations: NSObject {
    public typealias ImportScriptsCallback = (ServiceWorker, [URL]) throws -> [String]
    let registration: ServiceWorkerRegistrationProtocol
    let clients: WorkerClientsProtocol
    let importScripts: ImportScriptsCallback

    public init(registration: ServiceWorkerRegistrationProtocol? = nil, clients: WorkerClientsProtocol? = nil, importScripts: @escaping ImportScriptsCallback) {
        self.registration = registration ?? EmptyServiceWorkerRegistration()
        self.clients = clients ?? EmptyWorkerClients()
        self.importScripts = importScripts
    }
    
    public init(registration: ServiceWorkerRegistrationProtocol? = nil, clients: WorkerClientsProtocol? = nil) {
        self.registration = registration ?? EmptyServiceWorkerRegistration()
        self.clients = clients ?? EmptyWorkerClients()
        self.importScripts = EmptyImportScripts.callback
    }
}
