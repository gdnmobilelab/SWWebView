//
//  WebSQLDatabase.swift
//  ServiceWorker
//
//  Created by alastair.coote on 02/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol WebSQLDatabaseExports: JSExport {
    func transaction(_: JSValue, _: JSValue)
}

@objc class WebSQLDatabase: NSObject, WebSQLDatabaseExports {

    let connection: SQLiteConnection

    init(at path: URL) throws {
        self.connection = try SQLiteConnection(path)
    }

    func transaction(_ withCallback: JSValue, _ completeCallback: JSValue) {
        _ = WebSQLTransaction(in: self.connection, withCallback: withCallback, completeCallback: completeCallback)
    }

    deinit {
        self.close()
    }

    func close() {
        do {
            if self.connection.open == true {
                try self.connection.close()
            }
        } catch {
            Log.error?("Could not close WebSQL connection")
        }
    }

    static func openDatabase(for worker: ServiceWorker, name: String) throws -> WebSQLDatabase {

        guard let host = worker.url.host else {
            throw ErrorMessage("Worker URL has no host, cannot create WebSQL function")
        }

        guard let escapedOrigin = host.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw ErrorMessage("Could not create percent-escaped origin for WebSQL")
        }

        guard let escapedName = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw ErrorMessage("Could not escape SQLite database filename")
        }

        guard let storageURL = worker.delegate?.storageURL else {
            throw ErrorMessage("You must set a ServiceWorkerDelegate with a storageURL property to use storage")
        }

        let dbDirectory = storageURL
            .appendingPathComponent(escapedOrigin, isDirectory: true)
            .appendingPathComponent("websql", isDirectory: true)

        let dbURL = dbDirectory
            .appendingPathComponent(escapedName)
            .appendingPathExtension("sqlite")

        if FileManager.default.fileExists(atPath: dbDirectory.path) == false {
            try FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let db = try WebSQLDatabase(at: dbURL)
        return db
    }
}
