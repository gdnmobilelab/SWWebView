//
//  SQLiteResultSet.swift
//  Shared
//
//  Created by alastair.coote on 19/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3

public class SQLiteResultSet {

    fileprivate let statement: OpaquePointer
    let columnNames: [String]
    var open = true

    init(statement: OpaquePointer) {
        self.statement = statement

        let numColumns = sqlite3_column_count(self.statement)
        var columnNames: [String] = []

        var currentColumn: Int32 = 0
        while currentColumn < numColumns {
            let name = String(cString: sqlite3_column_name(self.statement, currentColumn))
            columnNames.append(name)
            currentColumn = currentColumn + 1
        }

        self.columnNames = columnNames
    }

    public func next() -> Bool {
        return sqlite3_step(self.statement) == SQLITE_ROW
    }

    fileprivate func nullCheck(_ idx: Int32) -> Bool {
        return sqlite3_column_type(self.statement, idx) == SQLITE_NULL
    }

    fileprivate func idxForColumnName(_ name: String) throws -> Int32 {
        let idx = columnNames.index(of: name)

        if idx == nil {
            throw ErrorMessage("Column does not exist in result set")
        }
        return Int32(idx!)
    }

    public func string(_ name: String) throws -> String? {

        let idx = try idxForColumnName(name)

        if self.nullCheck(idx) {
            return nil
        }

        let result = sqlite3_column_text(statement, idx)!
        return String(cString: result)
    }

    public func int(_ name: String) throws -> Int? {
        let idx = try idxForColumnName(name)

        if self.nullCheck(idx) {
            return nil
        }

        let result = sqlite3_column_int(statement, idx)
        return Int(result)
    }

    public func int64(_ name: String) throws -> Int64? {
        let idx = try idxForColumnName(name)

        if self.nullCheck(idx) {
            return nil
        }

        let result = sqlite3_column_int64(statement, idx)
        return Int64(result)
    }

    public func double(_ name: String) throws -> Double? {
        let idx = try idxForColumnName(name)

        if self.nullCheck(idx) {
            return nil
        }

        let result = sqlite3_column_double(statement, idx)

        return result
    }

    public func data(_ name: String) throws -> Data? {
        let idx = try idxForColumnName(name)

        if self.nullCheck(idx) {
            return nil
        }

        let result = sqlite3_column_blob(statement, idx)
        let length = sqlite3_column_bytes(statement, idx)

        return Data(bytes: result!, count: Int(length))
    }

    public func url(_ name: String) throws -> URL? {
        let str = try string(name)
        if let strVal = str {
            return URL(string: strVal)
        }
        return nil
    }

    public func getColumnType(_ name: String) throws -> SQLiteDataType {

        let idx = try idxForColumnName(name)
        let colType = sqlite3_column_type(self.statement, idx)

        if colType == SQLITE_TEXT {
            return .Text
        } else if colType == SQLITE_INTEGER {
            return .Int
        } else if colType == SQLITE_BLOB {
            return .Blob
        } else if colType == SQLITE_FLOAT {
            return .Float
        } else if colType == SQLITE_NULL {
            return .Null
        } else {
            throw ErrorMessage("Did not recognise SQLite data type: \(colType)")
        }
    }
}
