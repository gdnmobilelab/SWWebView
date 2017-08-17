//
//  WebSQLResultSet.swift
//  ServiceWorker
//
//  Created by alastair.coote on 03/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol WebSQLResultSetProtocol: JSExport {
    var insertId: Int64 { get }
    var rowsAffected: Int { get }
    var rows: [Any] { get }
}

@objc class WebSQLResultSet: NSObject, WebSQLResultSetProtocol {

    let insertId: Int64
    let rowsAffected: Int
    var rows: [Any]

    init(resultSet: SQLiteResultSet, connection: SQLiteConnection) throws {

        self.insertId = connection.lastInsertRowId
        self.rowsAffected = connection.lastNumberChanges

        self.rows = []

        while resultSet.next() {

            var row = [String: Any?]()

            try resultSet.columnNames.forEach { name in

                let colType = try resultSet.getColumnType(name)

                if colType == .Text {
                    row[name] = try resultSet.string(name)
                } else if colType == .Int {
                    row[name] = try resultSet.int(name)
                } else if colType == .Float {
                    row[name] = try resultSet.double(name)
                } else if colType == .Null {
                    row[name] = NSNull()
                } else if colType == .Blob {
                    // Obviously this isn't correct, but WebSQL doesn't support
                    // binary blobs
                    row[name] = try resultSet.string(name)
                }
            }

            self.rows.append(row)
        }
    }
}
