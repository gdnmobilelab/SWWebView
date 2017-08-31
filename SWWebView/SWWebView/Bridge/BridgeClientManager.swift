//
//  BridgeClientManager.swift
//  SWWebView
//
//  Created by alastair.coote on 28/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker
import ServiceWorkerContainer

public class BridgeClientManager: WorkerClientsProtocol {

    let workerFactory: WorkerFactory

    public init() {
        self.workerFactory = WorkerFactory()
        self.workerFactory.clientsDelegate = self
    }

    public func get(id _: String, worker _: ServiceWorker, _: (Error?, ClientProtocol?) -> Void) {
    }

    public func matchAll(options _: ClientMatchAllOptions, _: (Error?, [ClientProtocol]?) -> Void) {
    }

    public func openWindow(_: URL, _: (Error?, ClientProtocol?) -> Void) {
    }

    public func claim(_: (Error?) -> Void) {
    }
}
