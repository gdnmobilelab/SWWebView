import Foundation
import SQLite3
import PromiseKit

// These aren't imported correctly from SQLite3, so we have to define them:
// https://stackoverflow.com/a/26884081/470339

private let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 100% sure I will regret this, but the SQLite libraries I could find for Swift didn't support
/// streaming, which we make heavy use of. Plus, I'm concerned about using SQLite in low memory
/// conditions, like the Notification Service Extension, so we might need to heavily customise
/// some stuff later on. Therefore, our own quick and dirty SQLite implementation.
public class SQLiteConnection {

    var db: OpaquePointer?
    public let url: URL

    var open: Bool {
        return self.db != nil
    }

    /// I was using this in testing but it turned out to not be necessary. I've left it in because
    /// there's an outside change we'll still need to use it when dealing cross-process issues.
    static var temporaryStoreDirectory: URL?

    public init(_ dbURL: URL) throws {
        self.url = dbURL
        let open = sqlite3_open_v2(dbURL.path.cString(using: String.Encoding.utf8), &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)

        if open != SQLITE_OK || self.db == nil {
            throw ErrorMessage("Could not create SQLite database instance: \(open)")
        }

        // Again to concerns about memory usage - trying to see if setting this reduces it:

        try self.exec(sql: "PRAGMA cache_size = 0;")

        if let tempStore = SQLiteConnection.temporaryStoreDirectory {
            try self.exec(sql: "PRAGMA temp_store_directory = '\(tempStore.path)';")
        }
    }

    deinit {

        // We'll automatically close any SQLite connection when it is dereferenced.

        do {
            if self.open {
                try self.close()
            }
        } catch {
            Log.error?("Failed to automatically close a SQLite connection on deinit: \(error)")
        }
    }

    /// A way to run a callback with a self-closing database connection. Opens, runs callback, closes, then
    /// passes whatever the callback returned back.
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

    /// Much like the other inConnection() call, except this one supports promises, and waits for them to
    /// resolve before closing the database connection.
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

    /// Quick wrapper to convert a SQLite error into a native one.
    func throwSQLiteError(_ err: UnsafeMutablePointer<Int8>?) throws {

        guard let errExists = err else {
            throw ErrorMessage("SQLITE return value was unexpected, but no error message was returned")
        }

        let errMsg = String(cString: errExists)
        sqlite3_free(errExists)
        throw ErrorMessage("SQLite ERROR: \(errMsg)")
    }

    /// This just saves us writing guard let statments everywhere
    fileprivate func getDBPointer() throws -> OpaquePointer {
        if let dbExists = self.db {
            return dbExists
        }
        throw ErrorMessage("Connection is not open")
    }

    /// Executes a multi-line SQL statement. Doesn't support parameters
    /// or anything like that. Used in database migrations.
    public func exec(sql: String) throws {

        var zErrMsg: UnsafeMutablePointer<Int8>?
        let pointer = try getDBPointer()
        let rc = sqlite3_exec(pointer, sql, nil, nil, &zErrMsg)

        if rc != SQLITE_OK {
            try self.throwSQLiteError(zErrMsg)
        }
    }

    // I'm not totally sure these helpers are necessary, really

    public func beginTransaction() throws {
        return try self.exec(sql: "BEGIN TRANSACTION;")
    }

    public func rollbackTransaction() throws {
        return try self.exec(sql: "ROLLBACK TRANSACTION;")
    }

    public func commitTransaction() throws {
        return try self.exec(sql: "COMMIT TRANSACTION;")
    }

    public func inTransaction<T>(_ closure: () throws -> T) throws -> T {

        try self.beginTransaction()

        do {
            let result = try closure()
            try self.commitTransaction()
            return result

        } catch {
            do {
                try self.rollbackTransaction()
            } catch {
                Log.error?("Error when rolling back transaction: \(error)")
            }
            throw error
        }
    }

    /// SQLite has different binding functions for different data types - we try to cast an Any?
    /// object to various different types in order to make them compatible with the query. If we've
    /// passed in something totally unsupported, it'll throw.
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

    /// Execute an update statement. Uses bindValue() to convert values into SQLite
    /// parameters.
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

    /// Does exactly the same as an update query, except that it'll return the row_id of
    /// the newly inserted row.
    public func insert(sql: String, values: [Any?]) throws -> Int64 {
        try self.update(sql: sql, values: values)

        guard let lastInserted = self.lastInsertRowId else {
            throw ErrorMessage("Could not fetch last inserted row ID")
        }
        return lastInserted
    }

    /// Mapping for: https://sqlite.org/c3ref/changes.html
    public var lastNumberChanges: Int? {
        guard let db = self.db else {
            return nil
        }
        return Int(sqlite3_changes(db))
    }

    /// Get the last ID inserted, if there is one.
    public var lastInsertRowId: Int64? {
        guard let db = self.db else {
            return nil
        }
        return sqlite3_last_insert_rowid(db)
    }

    /// SELECT statements use a callback format to manage the lifecycle of the result set - SQLite
    /// requires you to close it when you're done with it, but using this callback means we don't
    /// have to remember to do it ourselves.
    public func select<T>(sql: String, values: [Any?] = [], _ cb: (SQLiteResultSet) throws -> T) throws -> T {

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

    // SQLite blob streams can only set/read data on existing blobs, and cannot change their length. It requires
    // the row_id too, so usually needs a SELECT statement to precede this call.

    public func openBlobReadStream(table: String, column: String, row: Int64) throws -> SQLiteBlobReadStream {
        return SQLiteBlobReadStream(self, table: table, column: column, row: row)
    }

    public func openBlobWriteStream(table: String, column: String, row: Int64) throws -> SQLiteBlobWriteStream {
        return SQLiteBlobWriteStream(self, table: table, column: column, row: row)
    }
}
