//
//  WorkerRegistrationFactory.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 29/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

public class WorkerRegistrationFactory {

    let workerFactory: WorkerFactory

    fileprivate let activeRegistrations = NSHashTable<ServiceWorkerRegistration>.weakObjects()

    public init(withWorkerFactory workerFactory: WorkerFactory) {
        self.workerFactory = workerFactory
    }

    public func get(byId id: String) throws -> ServiceWorkerRegistration? {
        let active = activeRegistrations.allObjects.filter { $0.id == id }.first

        if active != nil {
            return active
        }

        return try CoreDatabase.inConnection { connection in

            try connection.select(sql: "SELECT * FROM registrations WHERE registration_id = ?", values: [id]) { rs -> ServiceWorkerRegistration? in

                if try rs.next() == false {
                    return nil
                }

                guard let id = try rs.string("registration_id") else {
                    throw ErrorMessage("No ID value for registration")
                }
                guard let scope = try rs.url("scope") else {
                    throw ErrorMessage("No URL value for registration")
                }

                var workerIDs: [RegistrationWorkerSlot: String] = [:]

                if let active = try rs.string("active") {
                    workerIDs[.active] = active
                }

                if let waiting = try rs.string("waiting") {
                    workerIDs[.waiting] = waiting
                }

                if let installing = try rs.string("installing") {
                    workerIDs[.installing] = installing
                }

                if let redundant = try rs.string("redundant") {
                    workerIDs[.redundant] = redundant
                }

                let registration = try ServiceWorkerRegistration(scope: scope, id: id, workerIDs: workerIDs, fromFactory: self)

                self.activeRegistrations.add(registration)

                return registration
            }
        }
    }

    public func get(byScope scope: URL) throws -> ServiceWorkerRegistration? {
        let active = self.activeRegistrations.allObjects.filter { $0.scope == scope }.first

        if active != nil {
            return active
        }

        let id = try CoreDatabase.inConnection { connection in

            try connection.select(sql: "SELECT registration_id FROM registrations WHERE scope = ?", values: [scope]) { rs -> String? in

                if try rs.next() == false {
                    return nil
                }

                guard let id = try rs.string("registration_id") else {
                    throw ErrorMessage("Registration has no scope")
                }

                return id
            }
        }

        if let idExists = id {
            return try self.get(byId: idExists)
        } else {
            return nil
        }
    }

    public func create(scope: URL) throws -> ServiceWorkerRegistration {

        return try CoreDatabase.inConnection { connection in
            let newRegID = UUID().uuidString
            _ = try connection.insert(sql: "INSERT INTO registrations (registration_id, scope) VALUES (?, ?)", values: [newRegID, scope])
            let reg = try ServiceWorkerRegistration(scope: scope, id: newRegID, workerIDs: [:], fromFactory: self)
            self.activeRegistrations.add(reg)
            return reg
        }
    }

    func createNewInstallingWorker(for url: URL, in registration: ServiceWorkerRegistration) throws -> ServiceWorker {

        let worker = try self.workerFactory.create(for: url, in: registration)

        try registration.set(workerSlot: .installing, to: worker)

        return worker
    }

    /// A special case. If an installing worker fails we don't want to make it redundant, we
    /// just delete it entirely.
    func clearInstallingWorker(in registration: ServiceWorkerRegistration) throws {

        guard let installing = registration.installing else {
            throw ErrorMessage("Cannot clear installing worker when there is none")
        }

        try registration.set(workerSlot: .installing, to: nil, makeOldRedundant: false)
        try self.workerFactory.delete(worker: installing)
    }

    func getReadyRegistration(for containerURL: URL) throws -> ServiceWorkerRegistration? {
        return try CoreDatabase.inConnection { db in

            // Not enough to just have an 'active' worker, it also needs to be in an 'activated'
            // state (i.e. not 'activating')

            try db.select(sql: """
                SELECT r.registration_id
                FROM registrations AS r
                INNER JOIN workers AS w
                    ON r.active = w.worker_id
                WHERE ? LIKE (r.scope || '%')
                AND w.install_state == "activated"
                ORDER BY length(scope) DESC
                LIMIT 1
            """, values: [containerURL]) { resultSet in

                if try resultSet.next() == false {
                    return nil
                }

                guard let id = try resultSet.string("registration_id") else {
                    throw ErrorMessage("Ready registration does not have an ID value")
                }

                return try self.get(byId: id)
            }
        }
    }

    func update(_ registration: ServiceWorkerRegistration, workerSlot: RegistrationWorkerSlot, to worker: ServiceWorker?) throws {

        try CoreDatabase.inConnection { db in

            _ = try db.insert(sql: """
                UPDATE registrations
                    SET '\(workerSlot.rawValue)' = ?
                WHERE registration_id = ?
            """, values: [
                worker?.id,
                registration.id
            ])
        }
    }

    func delete(_ registration: ServiceWorkerRegistration) throws {
        try CoreDatabase.inConnection { db in
            try db.update(sql: "DELETE FROM registrations WHERE registration_id = ?", values: [registration.id])
        }
        self.activeRegistrations.remove(registration)
    }
}
