//
//  SQLiteQueuedSession.swift
//  ServiceWorker
//
//  Created by alastair.coote on 16/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

class SQLiteQueuedSession {
    
    var underlyingConnection: SQLiteConnection?
    
    init(with connection: SQLiteConnection) {
        self.underlyingConnection = connection
    }
    
    fileprivate func connectionCheck() throws {
        if self.underlyingConnection == nil {
            throw ErrorMessage("You are outside of the session scope. Please ensure you are only using this inside a withConnection promise chain.")
        }
    }
    
    func invalidate() {
        self.underlyingConnection = nil
    }
    
    func select<T>(sql: String, values: [Any], _ cb: (SQLiteResultSet) throws -> T) throws -> T {
        try self.connectionCheck()
        return try self.underlyingConnection!.select(sql: sql, cb)
    }
    
    func insert(sql: String, values: [Any]) throws -> Int64 {
        try self.connectionCheck()
        return try self.underlyingConnection!.insert(sql: sql, values: values)
    }
    
    func update(sql: String, values: [Any]) throws {
        try self.connectionCheck()
        return try self.underlyingConnection!.update(sql: sql, values: values)
    }
    
    func exec(sql: String) throws {
        try self.connectionCheck()
        return try self.underlyingConnection!.exec(sql: sql)
    }
    
}
