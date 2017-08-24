//
//  CoreDatabase.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 24/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import ServiceWorker

public class CoreDatabase {

    //    public static let dbPath = SharedResources.appGroupStorage.appendingPathComponent("core.db")
    public static var dbDirectory: URL?

    static var dbPath: URL? {
        return self.dbDirectory?.appendingPathComponent("core.db")
    }

    /// The migrations only change with a new version of the app, so as long as we've
    /// checked for migrations once per app launch, we're OK to not check again
    static var dbMigrationCheckDone = false

    fileprivate static func doMigrationCheck() throws {

        if self.dbPath == nil {
            throw ErrorMessage("CoreDatabase.dbPath must be set on app startup")
        }

        if self.dbMigrationCheckDone == false {

            Log.info?("Migration check for core DB not done yet, doing it now...")

            let migrations = URL(fileURLWithPath: Bundle(for: CoreDatabase.self).bundlePath, isDirectory: true)
                .appendingPathComponent("DatabaseMigrations", isDirectory: true)
                .appendingPathComponent("core", isDirectory: true)

            // This might be the first time it's being run, in which case, we need to ensure we have the
            // directory structure ready.
            try FileManager.default.createDirectory(at: dbPath!.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

            _ = try DatabaseMigration.check(dbPath: dbPath!, migrationsPath: migrations)
            dbMigrationCheckDone = true
        }
    }

    // OK, running into lock issues so now we're sticking with one connection.
    fileprivate static var conn: SQLiteConnection?

    public static func inConnection<T>(_ cb: (SQLiteConnection) throws -> T) throws -> T {

        if self.dbPath == nil {
            throw ErrorMessage("CoreDatabase.dbPath must be set on app startup")
        }

        try self.doMigrationCheck()

        if self.conn == nil {
            self.conn = try SQLiteConnection(self.dbPath!)
        }

        return try cb(self.conn!)
        //        return try SQLiteConnection.inConnection(self.dbPath!, cb)
    }

    public static func inConnection<T>(_ cb: @escaping (SQLiteConnection) throws -> Promise<T>) -> Promise<T> {

        return firstly {

            if self.dbPath == nil {
                throw ErrorMessage("CoreDatabase.dbPath must be set on app startup")
            }
            try self.doMigrationCheck()
            if self.conn == nil {
                self.conn = try SQLiteConnection(self.dbPath!)
            }
            return try cb(self.conn!)
            //            return SQLiteConnection.inConnection(self.dbPath!, cb)
        }
    }

    static func createConnection() throws -> SQLiteConnection {
        if self.dbPath == nil {
            throw ErrorMessage("CoreDatabase.dbPath must be set on app startup")
        }
        return try SQLiteConnection(self.dbPath!)
    }
}
