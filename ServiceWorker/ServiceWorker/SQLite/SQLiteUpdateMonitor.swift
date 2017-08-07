//
//  SQLiteUpdateMonitor.swift
//  Shared
//
//  Created by alastair.coote on 20/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3

public class SQLiteUpdateMonitor {

    // Turns out this is useless as it doesn't work across connections

    typealias Callback = (SQLiteUpdateOperation, String, Int64) -> Void

    fileprivate let conn: SQLiteConnection

    fileprivate var listeners: [Int: Callback] = [:]

    init(_ conn: SQLiteConnection) {
        self.conn = conn

        // The update hook is a little weird - we need to get an unsafe pointer to this specific class instance,
        // then refer to it later. The Swift/C bridge doesn't let us do this any other way.

        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        sqlite3_update_hook(self.conn.db!, { hookId, operation, dbName, tableName, rowId in

            let mySelf = Unmanaged<SQLiteUpdateMonitor>.fromOpaque(hookId!).takeUnretainedValue()
            mySelf.update(hookId: hookId, operation: operation, dbName: String(cString: dbName!), tableName: String(cString: tableName!), rowId: rowId)

        }, observer)
    }

    fileprivate func update(hookId _: UnsafeMutableRawPointer?, operation: Int32, dbName _: String?, tableName: String?, rowId: Int64) {

        var operationEnum: SQLiteUpdateOperation = SQLiteUpdateOperation.Insert
        if operation == SQLITE_UPDATE {
            operationEnum = SQLiteUpdateOperation.Update
        }
        if operation == SQLITE_DELETE {
            operationEnum = SQLiteUpdateOperation.Delete
        }

        self.listeners.values.forEach { $0(operationEnum, tableName!, rowId) }
    }

    func addListener(_ callback: @escaping Callback) -> Int {

        var i = 0
        while i > -1 {
            if self.listeners[i] == nil {
                self.listeners[i] = callback
                return i
            }
            i = i + 1
        }
        return -1
    }

    func removeListener(_ key: Int) {
        self.listeners[key] = nil
    }
}
