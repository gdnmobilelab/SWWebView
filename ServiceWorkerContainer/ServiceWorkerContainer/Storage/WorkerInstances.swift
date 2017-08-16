//
//  WorkerInstances.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 24/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

/// We keep track of the workers currently in use, so that we don't ever duplicate them.
class WorkerInstances {

    fileprivate static let workerStorage = NSHashTable<ServiceWorker>.weakObjects()

    static func get(id: String) throws -> ServiceWorker {
        let workerWanted = workerStorage.allObjects.filter { $0.id == id }

        if workerWanted.first != nil {
            return workerWanted.first!
        }

        let dbWorker = try CoreDatabase.inConnection { db -> ServiceWorker in
            return try db.select(sql: "SELECT scope, url, install_state FROM workers WHERE worker_id = ?", values: [id]) { (resultSet) -> ServiceWorker in
                if resultSet.next() == false {
                    throw ErrorMessage("Worker does not exist")
                }

                let registration = try ServiceWorkerRegistration.getOrCreate(scope: try resultSet.url("scope")!)
                let state = ServiceWorkerInstallState(rawValue: try resultSet.string("install_state")!)!

                return ServiceWorker(id: id, url: try resultSet.url("url")!, registration: registration, state: state, loadContent: ServiceWorkerHooks.loadContent)
            }
        }

        dbWorker.importScripts = ServiceWorkerHooks.importScripts
        workerStorage.add(dbWorker)

        return dbWorker
    }
}
