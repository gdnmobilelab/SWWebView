//
//  ServiceWorkerRegistration.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import ServiceWorker

public class ServiceWorkerRegistration: ServiceWorkerRegistrationProtocol {

    public func showNotification(title _: String) {
    }

    typealias RegisterCallback = (Error?) -> Void

    public let scope: URL
    public var active: ServiceWorker?
    public var waiting: ServiceWorker?
    public var installing: ServiceWorker?
    public var redundant: ServiceWorker?

    fileprivate init(scope: URL) {
        self.scope = scope
    }

    func update() -> Promise<Void> {

        return firstly {

            var updateWorker: ServiceWorker?

            // Not sure of exactly how the logic should work here (do waiting workers count?) but we'll use both for now.
            // Ignoring installing workers because updating a worker that's currently installing makes no sense.

            if self.active != nil {
                updateWorker = self.active
            } else if self.waiting != nil {
                updateWorker = self.waiting
            }

            guard let worker = updateWorker else {
                throw ErrorMessage("No existing worker to update")
            }

            let request = try self.getUpdateRequest(forExistingWorker: worker)

            return FetchOperation.fetch(request)
                .then { res in

                    if res.status == 304 {
                        Log.info?("Ran update check for \(worker.url), received Not Modified response")
                        return Promise(value: ())
                    }

                    if res.ok != true {
                        throw ErrorMessage("Ran update check for \(worker.url), received unknown \(res.status) response")
                    }

                    return self.processHTTPResponse(res, byteCompareWorker: worker)
                }
        }
    }

    fileprivate func getUpdateRequest(forExistingWorker worker: ServiceWorker) throws -> FetchRequest {

        return try CoreDatabase.inConnection { db in

            let request = FetchRequest(url: worker.url)

            let existingHeaders = try db.select(sql: "SELECT headers FROM workers WHERE worker_id = ?", values: [worker.id]) { resultSet -> FetchHeaders? in

                if resultSet.next() == false {
                    return nil
                }

                let jsonString = try resultSet.string("headers")!
                return try FetchHeaders.fromJSON(jsonString)
            }

            // We attempt to use Last-Modified and ETag headers to minimise the amount of code we're downloading
            // as part of this update process. If we are updating an existing worker, we grab the headers seen at
            // the time.

            if let etag = existingHeaders?.get("ETag") {
                request.headers.append("If-None-Match", etag)
            }
            if let lastMod = existingHeaders?.get("Last-Modified") {
                request.headers.append("If-Modified-Since", lastMod)
            }

            return request
        }
    }

    func register(_ workerURL: URL) -> Promise<Void> {
        return FetchOperation.fetch(workerURL)
            .then { res in

                if res.ok == false {
                    throw ErrorMessage("Did not receive a valid response")
                }

                return self.processHTTPResponse(res)
            }
    }

    fileprivate func isWorkerByteIdentical(existingWorkerID: String, newHash: Data, db: SQLiteConnection) throws -> Bool {
        let existingHash = try db.select(sql: "SELECT content_hash FROM workers WHERE worker_id = ?", values: [existingWorkerID]) { resultSet -> Data in

            if resultSet.next() == false {
                throw ErrorMessage("Worker does not exist")
            }

            return try resultSet.data("content_hash")!
        }

        return existingHash == newHash
    }

    fileprivate func insertWorker(fromResponse res: FetchResponseProtocol, intoDatabase db: SQLiteConnection) -> Promise<(String, Data)> {

        return firstly { () -> Promise<(String, Data)> in

            let length = try res.internalResponse.getContentLength()

            let newWorkerID = UUID().uuidString
            let rowID = try db.insert(sql: """
                INSERT INTO workers
                    (worker_id, url, headers, content, install_state, scope)
                VALUES
                    (?,?,?,zeroblob(?),?,?)
            """, values: [
                newWorkerID,
                res.url,
                try res.headers.toJSON(),
                length,
                ServiceWorkerInstallState.downloading.rawValue,
                self.scope,
            ])

            let writeStream = db.openBlobWriteStream(table: "workers", column: "content", row: rowID)
            let reader = try res.getReader()

            return writeStream.pipeReadableStream(stream: reader)
                .then { hash -> (String, Data) in

                    try db.update(sql: "UPDATE workers SET content_hash = ? WHERE worker_id = ?", values: [hash, newWorkerID])

                    return (newWorkerID, hash)
                }
        }
    }

    func processHTTPResponse(_ res: FetchResponseProtocol, byteCompareWorker: ServiceWorker? = nil) -> Promise<Void> {

        return CoreDatabase.inConnection { db in
            self.insertWorker(fromResponse: res, intoDatabase: db)
                .then { workerID, hash in

                    if byteCompareWorker != nil {
                        // In addition to HTTP headers, we also check to see if the content of the worker has
                        // changed at all. Because we're tring to save memory, we use the hash value rather than
                        // the full body.

                        if try self.isWorkerByteIdentical(existingWorkerID: byteCompareWorker!.id, newHash: hash, db: db) {

                            // Worker is identical. Delete it and stop any further operations.
                            try db.update(sql: "DELETE FROM workers WHERE worker_id = ?", values: [workerID])
                            return Promise(value: ())
                        }
                    }

                    let worker = try WorkerInstances.get(id: workerID)

                    return self.install(worker: worker, in: db)
                        .then {

                            // Workers move from installed directly to activating if they have called
                            // self.skipWaiting() OR if we have no active worker currently.

                            if worker.skipWaitingStatus == true || self.active == nil {
                                return self.activate(worker: worker, in: db)
                            } else {
                                return Promise(value: ())
                            }
                        }
                        .recover { error -> Void in

                            // If either the install or activate processes fail, we update the worker
                            // state to redundant and kill it.

                            worker.destroy()
                            try self.updateWorkerStatus(db: db, worker: worker, newState: .redundant)
                            throw error
                        }
                }
        }
    }

    fileprivate func install(worker: ServiceWorker, in db: SQLiteConnection) -> Promise<Void> {

        let ev = ExtendableEvent(type: "install")

        return firstly { () -> Promise<Void> in
            try self.updateWorkerStatus(db: db, worker: worker, newState: .installing)
            return worker.dispatchEvent(ev)
        }.then { _ in
            ev.resolve(in: worker)
        }.then {
            try self.updateWorkerStatus(db: db, worker: worker, newState: .installed)
        }
    }

    fileprivate func activate(worker: ServiceWorker, in db: SQLiteConnection) -> Promise<Void> {

        // The spec is a little weird here. A worker with the state of "activating" should go
        // into the "active" slot, but if that activation fails we'd then be left with no active
        // worker. So for the time being, we're storing a reference to the current active worker
        // (if it exists) and restoring it, if the activation fails.

        let currentActive = active

        let ev = ExtendableEvent(type: "activate")

        return firstly { () -> Promise<Void> in
            try self.updateWorkerStatus(db: db, worker: worker, newState: .activating)
            return worker.dispatchEvent(ev)
        }
        .then { _ in
            ev.resolve(in: worker)
        }
        .then {
            try self.updateWorkerStatus(db: db, worker: worker, newState: .activated)
        }
        .recover { error -> Void in
            self.active = currentActive
            throw error
        }
    }

    func clearWorkerFromAllStatuses(worker: ServiceWorker) {
        if self.active == worker {
            self.active = nil
        } else if self.waiting == worker {
            self.waiting = nil
        } else if self.installing == worker {
            self.installing = nil
        } else if self.redundant == worker {
            self.redundant = nil
        }
    }

    func updateWorkerStatus(db: SQLiteConnection, worker: ServiceWorker, newState: ServiceWorkerInstallState) throws {

        // If there's already a worker in the slot we want, we need to update its state
        var existingWorker: ServiceWorker?
        if newState == .installing {
            existingWorker = self.installing
        } else if newState == .installed {
            existingWorker = self.waiting
        } else if newState == .activating || newState == .activated {
            existingWorker = self.active
        }

        if existingWorker != nil && existingWorker != worker {
            // existingWorker != worker because it'll be the same worker when going from activating to activated
            try db.update(sql: "UPDATE workers SET install_state = ? WHERE worker_id = ?", values: [ServiceWorkerInstallState.redundant.rawValue, existingWorker!.id])
            existingWorker!.state = .redundant
            self.redundant = existingWorker
        }

        try db.update(sql: "UPDATE workers SET install_state = ? WHERE worker_id = ?", values: [newState.rawValue, worker.id])
        worker.state = newState
        self.clearWorkerFromAllStatuses(worker: worker)
        if newState == .installing {
            self.installing = worker
        } else if newState == .installed {
            self.waiting = worker
        } else if newState == .activating || newState == .activated {
            self.active = worker
        } else if newState == .redundant {
            self.redundant = worker
        }
    }

    fileprivate static let activeInstances = NSHashTable<ServiceWorkerRegistration>.weakObjects()

    public static func get(scope: URL) throws -> ServiceWorkerRegistration? {

        let active = activeInstances.allObjects.filter { $0.scope == scope }.first

        if active != nil {
            return active
        }

        return try CoreDatabase.inConnection { connection in

            try connection.select(sql: "SELECT * FROM registrations WHERE scope = ?", values: [scope.absoluteString]) { rs -> ServiceWorkerRegistration? in

                if rs.next() == false {
                    // If we don't already have a registration, return nil (get() doesn't create one)
                    return nil
                }

                let reg = ServiceWorkerRegistration(scope: scope)

                // Need to add this now, as WorkerInstances.get() uses our static storage and
                // we don't want to get into a loop
                self.activeInstances.add(reg)

                if let activeId = try rs.string("active") {
                    reg.active = try WorkerInstances.get(id: activeId)
                }
                if let waitingId = try rs.string("waiting") {
                    reg.waiting = try WorkerInstances.get(id: waitingId)
                }
                if let installingId = try rs.string("installing") {
                    reg.installing = try WorkerInstances.get(id: installingId)
                }
                if let redundantId = try rs.string("redundant") {
                    reg.redundant = try WorkerInstances.get(id: redundantId)
                }

                return reg
            }
        }
    }

    public static func create(scope: URL) throws -> ServiceWorkerRegistration {

        return try CoreDatabase.inConnection { connection in
            _ = try connection.insert(sql: "INSERT INTO registrations (scope) VALUES (?)", values: [scope])
            let reg = ServiceWorkerRegistration(scope: scope)
            self.activeInstances.add(reg)
            return reg
        }
    }

    public static func getOrCreate(scope: URL) throws -> ServiceWorkerRegistration {

        if let existing = try self.get(scope: scope) {
            return existing
        } else {
            return try self.create(scope: scope)
        }
    }
}
