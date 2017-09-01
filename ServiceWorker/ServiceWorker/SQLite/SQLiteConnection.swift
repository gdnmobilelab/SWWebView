//
//  SQLiteConnection.swift
//  Shared
//
//  Created by alastair.coote on 19/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3
import PromiseKit

private let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public class SQLiteConnection {

    var db: OpaquePointer?
    var open: Bool {
        return self.db != nil
    }

    static var temporaryStoreDirectory: URL?

    public init(_ dbURL: URL) throws {

        let open = sqlite3_open_v2(dbURL.path.cString(using: String.Encoding.utf8), &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)

        if open != SQLITE_OK || self.db == nil {
            throw ErrorMessage("Could not create SQLite database instance: \(open)")
        }

        try self.exec(sql: "PRAGMA cache_size = 0;")
        if let tempStore = SQLiteConnection.temporaryStoreDirectory {
            try self.exec(sql: "PRAGMA temp_store_directory = '\(tempStore.path)';")
        }
    }

    public static func inConnection<T>(_ dbURL: URL, _ cb: ((SQLiteConnection) throws -> T)) throws -> T {

        let conn = try SQLiteConnection(dbURL)
        do {
            let result = try cb(conn)
            try conn.close()
            return result
        } catch {
            try conn.close()
            throw error
        }
    }

    public static func inConnection<T>(_ dbURL: URL, _ cb: @escaping ((SQLiteConnection) throws -> Promise<T>)) -> Promise<T> {

        return firstly {
            Promise(value: try SQLiteConnection(dbURL))
        }.then { conn in
            try cb(conn)
                .always {
                    do {
                        try conn.close()
                    } catch {
                        Log.error?("Failed to close database")
                    }
                }
        }
    }

    public func close() throws {

        guard let db = self.db else {
            throw ErrorMessage("SQLite connection is not open")
        }

        let rc = sqlite3_close_v2(db)
        if rc != SQLITE_OK {
            throw ErrorMessage("Could not close SQLite Database: Error code \(rc)")
        }

        self.db = nil

        let freed = sqlite3_release_memory(Int32.max)
        if freed > 0 {
            Log.info?("Freed \(freed) bytes of SQLite memory")
        }
    }

    fileprivate func throwSQLiteError(_ err: UnsafeMutablePointer<Int8>?) throws {

        guard let errExists = err else {
            throw ErrorMessage("SQLITE return value was unexpected, but no error message was returned")
        }

        let errMsg = String(cString: errExists)
        sqlite3_free(errExists)
        throw ErrorMessage("SQLite ERROR: \(errMsg)")
    }

    fileprivate func getDBPointer() throws -> OpaquePointer {
        if let dbExists = self.db {
            return dbExists
        }
        throw ErrorMessage("Connection is not open")
    }

    public func exec(sql: String) throws {

        var zErrMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(try getDBPointer(), sql, nil, nil, &zErrMsg)
        if rc != SQLITE_OK {
            try self.throwSQLiteError(zErrMsg)
        }
    }

    public func beginTransaction() throws {
        var zErrMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(try getDBPointer(), "BEGIN TRANSACTION;", nil, nil, &zErrMsg)

        if rc != SQLITE_OK {
            try self.throwSQLiteError(zErrMsg)
        }
    }

    public func rollbackTransaction() throws {
        var zErrMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(try getDBPointer(), "ROLLBACK TRANSACTION;", nil, nil, &zErrMsg)

        if rc != SQLITE_OK {
            try self.throwSQLiteError(zErrMsg)
        }
    }

    public func commitTransaction() throws {
        var zErrMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(try getDBPointer(), "COMMIT TRANSACTION;", nil, nil, &zErrMsg)

        if rc != SQLITE_OK {
            try self.throwSQLiteError(zErrMsg)
        }
    }

    public func inTransaction<T>(_ closure: () throws -> T) throws -> T {

        var zErrMsg: UnsafeMutablePointer<Int8>?
        var rc = sqlite3_exec(try getDBPointer(), "BEGIN TRANSACTION;", nil, nil, &zErrMsg)

        if rc != SQLITE_OK {
            try self.throwSQLiteError(zErrMsg)
        }

        do {
            let result = try closure()
            rc = sqlite3_exec(try getDBPointer(), "; COMMIT TRANSACTION;", nil, nil, &zErrMsg)
            if rc != SQLITE_OK {
                try self.throwSQLiteError(zErrMsg!)
            }
            return result

        } catch {
            rc = sqlite3_exec(try self.getDBPointer(), "; ROLLBACK TRANSACTION;", nil, nil, &zErrMsg)
            throw error
        }
    }

    fileprivate func bindValue(_ statement: OpaquePointer, idx: Int32, value: Any?) throws {

        if value == nil {
            sqlite3_bind_null(statement, idx)
        } else if let int32Value = value as? Int32 {
            sqlite3_bind_int(statement, idx, int32Value)
        } else if let intValue = value as? Int {
            sqlite3_bind_int(statement, idx, Int32(intValue))
        } else if let int64Value = value as? Int64 {
            sqlite3_bind_int64(statement, idx, int64Value)
        } else if let stringValue = value as? String {
            sqlite3_bind_text(statement, idx, stringValue.cString(using: String.Encoding.utf8), -1, SQLITE_TRANSIENT)
        } else if let urlValue = value as? URL {
            let stringValue = urlValue.absoluteString
            sqlite3_bind_text(statement, idx, stringValue.cString(using: String.Encoding.utf8), -1, SQLITE_TRANSIENT)
        } else if let dataValue = value as? Data {
            _ = dataValue.withUnsafeBytes { body in
                sqlite3_bind_blob(statement, idx, body, Int32(dataValue.count), nil)
            }
        } /* else if let boolValue = value as? Bool {
         sqlite3_bind_int(statement, idx, boolValue ? 1 : 0)
         } */ else {
            throw ErrorMessage("Did not understand input data type")
        }
    }

    fileprivate func getLastError(_ dbPointer: OpaquePointer) -> ErrorMessage {
        let errMsg = String(cString: sqlite3_errmsg(dbPointer))
        return ErrorMessage(errMsg)
    }

    public func update(sql: String, values: [Any?]) throws {

        let db = try getDBPointer()

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql + ";", -1, &statement, nil) != SQLITE_OK {
            sqlite3_finalize(statement)
            throw self.getLastError(db)
        }

        guard let setStatement = statement else {
            throw ErrorMessage("SQLite statement was not created successfully")
        }

        do {
            let parameterCount = sqlite3_bind_parameter_count(setStatement)

            if values.count != parameterCount {
                throw ErrorMessage("Value array length is not equal to the parameter count")
            }

            for (offset, element) in values.enumerated() {
                // SQLite uses non-zero index for parameter numbers
                try self.bindValue(setStatement, idx: Int32(offset) + 1, value: element)
            }
            let step = sqlite3_step(setStatement)
            if step != SQLITE_DONE {
                throw self.getLastError(db)
            }

            sqlite3_finalize(setStatement)
        } catch {
            sqlite3_finalize(setStatement)
            throw error
        }
    }

    public func insert(sql: String, values: [Any?]) throws -> Int64 {
        try self.update(sql: sql, values: values)

        guard let lastInserted = self.lastInsertRowId else {
            throw ErrorMessage("Could not fetch last inserted row ID")
        }
        return lastInserted
    }

    public var lastNumberChanges: Int? {
        guard let db = self.db else {
            return nil
        }
        return Int(sqlite3_changes(db))
    }

    public var lastInsertRowId: Int64? {
        guard let db = self.db else {
            return nil
        }
        return sqlite3_last_insert_rowid(db)
    }

    public func select<T>(sql: String, values: [Any?], _ cb: (SQLiteResultSet) throws -> T) throws -> T {

        let db = try getDBPointer()

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql + ";", -1, &statement, nil) != SQLITE_OK {
            sqlite3_finalize(statement)
            throw self.getLastError(db)
        }

        guard let setStatement = statement else {
            throw ErrorMessage("SQLite statement pointer was not set successfully")
        }

        for (offset, element) in values.enumerated() {
            try self.bindValue(setStatement, idx: Int32(offset) + 1, value: element)
        }

        let rs = SQLiteResultSet(statement: setStatement)

        do {
            let result = try cb(rs)
            try rs.close()

            return result
        } catch {
            try rs.close()
            throw error
        }
    }

    public func select<T>(sql: String, _ cb: (SQLiteResultSet) throws -> T) throws -> T {
        return try self.select(sql: sql, values: [], cb)
    }

    public func openBlobReadStream(table: String, column: String, row: Int64) throws -> SQLiteBlobReadStream {

        return SQLiteBlobReadStream(try self.getDBPointer(), table: table, column: column, row: row)
    }

    public func openBlobWriteStream(table: String, column: String, row: Int64) throws -> SQLiteBlobWriteStream {

        return SQLiteBlobWriteStream(try self.getDBPointer(), table: table, column: column, row: row)
    }
}
