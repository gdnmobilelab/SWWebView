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
import JavaScriptCore

@objc public class ServiceWorkerRegistration: NSObject, ServiceWorkerRegistrationProtocol {

    public func showNotification(_ val: JSValue) -> JSValue {
        return JSValue(undefinedIn: val.context)
    }

    typealias RegisterCallback = (Error?) -> Void

    public let scope: URL
    public let id: String

    public var active: ServiceWorker? {
        return self.workers[.active]
    }

    public var waiting: ServiceWorker? {
        return self.workers[.waiting]
    }

    public var installing: ServiceWorker? {
        return self.workers[.installing]
    }

    public var redundant: ServiceWorker? {
        return self.workers[.redundant]
    }

    fileprivate var workers: [RegistrationWorkerSlot: ServiceWorker] = [:]

    internal func set(workerSlot: RegistrationWorkerSlot, to worker: ServiceWorker?, makeOldRedundant: Bool = true) throws {

        if let existingWorker = self.workers[workerSlot], makeOldRedundant {
            // If we already have a worker in this slot then we mark it as redudant. Maybe
            // further shutdown stuff to be done?
            try self.factory.workerFactory.update(worker: existingWorker, toInstallState: .redundant)
            self.workers[.redundant] = existingWorker
        }

        try self.factory.update(self, workerSlot: workerSlot, to: worker)

        if worker == nil {
            self.workers.removeValue(forKey: workerSlot)
        } else {
            self.workers[workerSlot] = worker
        }
        GlobalEventLog.notifyChange(self)
    }

    fileprivate let factory: WorkerRegistrationFactory

    internal init(scope: URL, id: String, workerIDs: [RegistrationWorkerSlot: String], fromFactory factory: WorkerRegistrationFactory) throws {

        self.scope = scope
        self.id = id

        self.factory = factory
        super.init()

        try workerIDs.forEach { key, workerID in
            self.workers[key] = try self.factory.workerFactory.get(id: workerID, withRegistration: self)
        }
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

            let request = try self.factory.workerFactory.getUpdateRequest(forExistingWorker: worker)

            return FetchOperation.fetch(request)
                .then { res in

                    if res.status == 304 {
                        Log.info?("Ran update check for \(worker.url), received Not Modified response")
                        return Promise(value: ())
                    }

                    if res.ok != true {
                        throw ErrorMessage("Ran update check for \(worker.url), received unknown \(res.status) response")
                    }

                    let newWorker = try self.factory.createNewInstallingWorker(for: request.url, in: self)

                    return self.processHTTPResponse(res, newWorker: newWorker, byteCompareWorker: worker)
                }
        }
    }

    typealias RegisterReturn = (ServiceWorker, Promise<Void>)
    func register(_ workerURL: URL) -> Promise<RegisterReturn> {

        // The install process is asynchronous and the register call doesn't wait for it.
        // So we create our stub in the database then return the promise immediately.

        return firstly { () -> Promise<RegisterReturn> in

            let worker = try self.factory.createNewInstallingWorker(for: workerURL, in: self)

            return FetchOperation.fetch(workerURL)
                .then { res -> RegisterReturn in

                    if res.ok == false {
                        // We couldn't fetch the worker JS, so we immediately delete the worker
                        try self.factory.clearInstallingWorker(in: self)
                        throw ErrorMessage("Received response code \(res.status)")
                    }

                    // Very weird layout here, but installation is a two-tiered process. We return
                    // immediately when we've created the stub worker, but we also want to return
                    // any errors to the webview even though it runs asynchronously.

                    return (worker, self.processHTTPResponse(res, newWorker: worker))
                }
        }
    }

    func processHTTPResponse(_ res: FetchResponseProtocol, newWorker: ServiceWorker, byteCompareWorker: ServiceWorker? = nil) -> Promise<Void> {

        return self.factory.workerFactory.update(worker: newWorker, setScriptResponse: res)
            .then { () -> Promise<Void> in

                if let compare = byteCompareWorker {
                    if try self.factory.workerFactory.isByteIdentical(newWorker, compare) == true {
                        Log.info?("New worker is byte identical to old one. Clearing installing worker...")
                        try self.factory.clearInstallingWorker(in: self)
                        return Promise(value: ())
                    }
                }

                return self.install(worker: newWorker)
                    .then {

                        // Workers move from installed directly to activating if they have called
                        // self.skipWaiting() OR if we have no active worker currently.

                        if newWorker.skipWaitingStatus == true || self.active == nil {
                            return self.activate(worker: newWorker)
                        } else {
                            return Promise(value: ())
                        }
                    }
            }
    }

    fileprivate func install(worker: ServiceWorker) -> Promise<Void> {

        return firstly {
            if self.installing != worker {
                throw ErrorMessage("Can only install a worker if it's in the installing slot")
            }

            let ev = ExtendableEvent(type: "install")
            return worker.dispatchEvent(ev)
                .then { _ in
                    ev.resolve(in: worker)
                }
        }
        .then { () -> Void in
            try self.factory.workerFactory.update(worker: worker, toInstallState: .installed)
            try self.set(workerSlot: .waiting, to: worker)
            try self.set(workerSlot: .installing, to: nil, makeOldRedundant: false)
        }
        .recover { error -> Void in
            try self.factory.workerFactory.update(worker: worker, toInstallState: .redundant)
            try self.set(workerSlot: .installing, to: nil)
            throw error
        }
    }

    fileprivate func activate(worker: ServiceWorker) -> Promise<Void> {

        // The spec is a little confusing here, but it seems like if
        // 'active' is empty our worker goes directly into that slot
        // even while it is activating. If not, it stays in waiting
        // while it activates.

        let moveToActiveImmediately = self.active == nil

        return firstly {

            if self.waiting != worker {
                throw ErrorMessage("Can only activate a worker if it's in the waiting slot")
            }

            if moveToActiveImmediately == true {
                try self.set(workerSlot: .active, to: worker)
                try self.set(workerSlot: .waiting, to: nil, makeOldRedundant: false)
            }

            try self.factory.workerFactory.update(worker: worker, toInstallState: .activating)

            let ev = ExtendableEvent(type: "activate")
            return worker.dispatchEvent(ev)
                .then { _ in
                    ev.resolve(in: worker)
                }
        }
        .then { () -> Void in
            try self.factory.workerFactory.update(worker: worker, toInstallState: .activated)
            if moveToActiveImmediately == false {
                try self.set(workerSlot: .active, to: worker)
                try self.set(workerSlot: .waiting, to: nil, makeOldRedundant: false)
            }
        }
        .recover { error -> Void in
            try self.factory.workerFactory.update(worker: worker, toInstallState: .redundant)
            if moveToActiveImmediately == true {
                try self.set(workerSlot: .active, to: nil)
            } else {
                try self.set(workerSlot: .waiting, to: nil)
            }
            throw error
        }
    }

    //    public static func getOrCreate(byScope scope: URL) throws -> ServiceWorkerRegistration {
    //        let existing = try self.get(byScope: scope)
    //        if existing != nil {
    //            return existing!
    //        } else {
    //            return try self.create(scope: scope)
    //        }
    //    }
    //
    //    public static func get(byScope scope: URL) throws -> ServiceWorkerRegistration? {
    //        let active = activeInstances.allObjects.filter { $0.scope == scope }.first
    //
    //        if active != nil {
    //            return active
    //        }
    //
    //        return try CoreDatabase.inConnection { connection in
    //
    //            try connection.select(sql: "SELECT * FROM registrations WHERE scope = ?", values: [scope]) { rs -> ServiceWorkerRegistration? in
    //
    //                return try self.fromResultSet(rs)
    //            }
    //        }
    //    }
    //
    //    fileprivate static func create(scope: URL) throws -> ServiceWorkerRegistration {
    //
    //        return try CoreDatabase.inConnection { connection in
    //            let newRegID = UUID().uuidString
    //            _ = try connection.insert(sql: "INSERT INTO registrations (registration_id, scope) VALUES (?, ?)", values: [newRegID, scope])
    //            let reg = ServiceWorkerRegistration(scope: scope, id: newRegID)
    //            self.activeInstances.add(reg)
    //            return reg
    //        }
    //    }

    fileprivate var _unregistered = false

    public var unregistered: Bool {
        return self._unregistered
    }

    public func unregister() -> Promise<Void> {

        return firstly {

            try self.factory.delete(self)
            self._unregistered = true
            GlobalEventLog.notifyChange(self)

            return Promise(value: ())

            //            let allWorkers = [self.active, self.waiting, self.installing, self.redundant]
            //
            //            try CoreDatabase.inConnection { db in
            //                try allWorkers.forEach { worker in
            //                    worker?.destroy()
            //                    if worker != nil {
            //                        try self.updateWorkerStatus(db: db, worker: worker!, newState: .redundant)
            //                    }
            //                }
            //
            //                try db.update(sql: "DELETE FROM registrations WHERE registration_id = ?", values: [self.id])
            //            }
            //
            //            self._unregistered = true
            //
            //            GlobalEventLog.notifyChange(self)
            //            ServiceWorkerRegistration.activeInstances.remove(self)
            //            return Promise(value: ())
        }
    }
}
