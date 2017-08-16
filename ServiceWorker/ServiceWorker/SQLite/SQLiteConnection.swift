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

fileprivate let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
fileprivate let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public class SQLiteConnection {

    var db: OpaquePointer?
    var open: Bool
    var url:URL
    var connectionQueue:DispatchQueue
    
    public init(_ dbURL: URL) throws {
        self.url = dbURL
        self.connectionQueue = DispatchQueue(label: "SQLite: " + dbURL.lastPathComponent)
        let open = sqlite3_open_v2(dbURL.path.cString(using: String.Encoding.utf8), &self.db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil)

        if open != SQLITE_OK {
            throw ErrorMessage("Could not create SQLite database instance: \(open)")
        }

        self.open = true
    }

    public func close() throws {
        return try connectionQueue.sync {
            self.open = false
            let rc = sqlite3_close_v2(self.db!)
            if rc != SQLITE_OK {
                throw ErrorMessage("Could not close SQLite Database: Error code \(rc)")
            }
            self.db = nil
            let freed = sqlite3_release_memory(Int32.max)
            if freed > 0 {
                Log.info?("Freed \(freed) bytes of SQLite memory")
            }
        }
    }

    fileprivate func throwSQLiteError(_ err: UnsafeMutablePointer<Int8>) throws {
        let errMsg = String(cString: err)
        sqlite3_free(err)
        throw ErrorMessage("SQLite ERROR: \(errMsg)")
    }

    public func exec(sql: String) throws {
        return try connectionQueue.sync {
            var zErrMsg: UnsafeMutablePointer<Int8>?
            let rc = sqlite3_exec(db!, sql, nil, nil, &zErrMsg)
            if rc != SQLITE_OK {
                try self.throwSQLiteError(zErrMsg!)
            }
        }
    }

//    public func beginTransaction() throws {
//        try self.exec(sql: "BEGIN TRANSACTION;")
//    }
//
//    public func rollbackTransaction() throws {
//        try self.exec(sql: "ROLLBACK TRANSACTION;")
//    }
//
//    public func commitTransaction() throws {
//        try self.exec(sql: "COMMIT TRANSACTION;")
//    }

    fileprivate func bindValue(_ statement: OpaquePointer, idx: Int32, value: Any) throws {

        if let int32Value = value as? Int32 {
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
        } else {
            throw ErrorMessage("Did not understand input data type")
        }
    }

    fileprivate func getLastError() -> ErrorMessage {
        let errMsg = String(cString: sqlite3_errmsg(db!))
        return ErrorMessage(errMsg)
    }

//    public func multiUpdate(sql: String, values: [[Any]]) throws {
//        
//        var statement: OpaquePointer?
//        
//        try connectionQueue.sync {
//            if sqlite3_prepare_v2(self.db!, sql + ";", -1, &statement, nil) != SQLITE_OK {
//                sqlite3_finalize(statement)
//                throw self.getLastError()
//            }
//        }
//
//        do {
//            let parameterCount = sqlite3_bind_parameter_count(statement)
//
//            for valueArray in values {
//
//                if valueArray.count != parameterCount {
//                    throw ErrorMessage("Value array length is not equal to the parameter count")
//                }
//
//                for (offset, element) in valueArray.enumerated() {
//                    // SQLite uses non-zero index for parameter numbers
//                    try self.bindValue(statement!, idx: Int32(offset) + 1, value: element)
//                }
//
//                if sqlite3_step(statement) != SQLITE_DONE {
//                    throw self.getLastError()
//                }
//
//                if sqlite3_reset(statement) != SQLITE_OK {
//                    throw self.getLastError()
//                }
//            }
//
//            if sqlite3_finalize(statement) != SQLITE_OK {
//                throw self.getLastError()
//            }
//        } catch {
//            sqlite3_finalize(statement)
//            throw error
//        }
//        
//    }

    public func update(sql: String, values: [Any]) throws {
        
        var statement: OpaquePointer?
        
        try connectionQueue.sync {
            if sqlite3_prepare_v2(self.db!, sql + ";", -1, &statement, nil) != SQLITE_OK {
                sqlite3_finalize(statement)
                throw self.getLastError()
            }
        }
        
        do {
            let parameterCount = sqlite3_bind_parameter_count(statement)
            
            
                if values.count != parameterCount {
                    throw ErrorMessage("Value array length is not equal to the parameter count")
                }
                
                for (offset, element) in values.enumerated() {
                    // SQLite uses non-zero index for parameter numbers
                    try self.bindValue(statement!, idx: Int32(offset) + 1, value: element)
                }
                
                if sqlite3_step(statement) != SQLITE_DONE {
                    throw self.getLastError()
                }

                if sqlite3_finalize(statement) != SQLITE_OK {
                    throw self.getLastError()
                }
        } catch {
            sqlite3_finalize(statement)
            throw error
        }
        
    }

    public func insert(sql: String, values: [Any]) throws -> Int64 {
        try self.update(sql: sql, values: values)
        return self.lastInsertRowId
    }
    
    public var lastNumberChanges:Int {
        get {
            return Int(sqlite3_changes(self.db!))
        }
    }
    
    public var lastInsertRowId:Int64 {
        get {
            return sqlite3_last_insert_rowid(self.db!)
        }
    }

    public func select<T>(sql: String, values: [Any], _ cb: (SQLiteResultSet) throws -> T) throws -> T {
        var statement: OpaquePointer?
        
        try connectionQueue.sync {
            if sqlite3_prepare_v2(self.db!, sql + ";", -1, &statement, nil) != SQLITE_OK {
                sqlite3_finalize(statement)
                throw self.getLastError()
            }
        }
          
        for (offset, element) in values.enumerated() {
            try self.bindValue(statement!, idx: Int32(offset) + 1, value: element)
        }
       
        let rs = SQLiteResultSet(statement: statement!)

        let result = try cb(rs)
        rs.open = false
        
        sqlite3_finalize(statement)

        return result
        
    }

    public func select<T>(sql: String, _ cb: (SQLiteResultSet) throws -> T) throws -> T {
        return try self.select(sql: sql, values: [], cb)
    }

    public func openBlobReadStream(table: String, column: String, row: Int64) -> SQLiteBlobReadStream {

        return SQLiteBlobReadStream(self.db!, table: table, column: column, row: row)
    }

    public func openBlobWriteStream(table: String, column: String, row: Int64) -> SQLiteBlobWriteStream {

        return SQLiteBlobWriteStream(self.db!, table: table, column: column, row: row)
    }
}
