//
//  SQLiteConnectionQueueTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 16/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

import XCTest
import FMDB
import PromiseKit
@testable import ServiceWorker
import SQLite3

class SQLiteQueuedConnectionTests: XCTestCase {
    
    let dbPath = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("test.db")
    
    override func setUp() {
        super.setUp()
        do {
            if FileManager.default.fileExists(atPath: self.dbPath.path) {
                try FileManager.default.removeItem(atPath: self.dbPath.path)
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testOperationsFailWhenOutsideOfChain() {
        
        var session:SQLiteQueuedSession? = nil
        
        SQLiteConnectionQueue.withConnection(to: self.dbPath) { db -> Int? in
            session = db
            return try db.select(sql: "SELECT 1 as num",values: []) { resultSet -> Int? in
                XCTAssertEqual(resultSet.next(), true)
                return try resultSet.int("num")
            }
        }
            .then { result -> Void in
                XCTAssertEqual(result, 1)
                do {
                    try session!.select(sql: "SELECT 1 as num", values: []) { resultSet -> Void in
                        XCTFail()
                    }
                    XCTFail()
                } catch {
                    // We want it to catch for a successful test
                }
        }
        .assertResolves()

    }
    
    func testSimultaneousOperationsShouldFailWithNoQueue() {
        
        XCTAssertThrowsError(try {
            let conn = try SQLiteConnection(self.dbPath)
            
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL
                );
            """)
            
            try conn.close()
            
            var keepInserting = true
            var errorFound:Error? = nil
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive).async {
                
                do {
                    let db = try SQLiteConnection(self.dbPath)
                    try db.update(sql: "DELETE FROM testtable", values: [])
                    try db.close()
                    keepInserting = false
                } catch {
                    keepInserting = false
                    errorFound = error
                }
            }
            
            let db = try SQLiteConnection(self.dbPath)
            var i = 0
            while i < 10000 && keepInserting == true {
                //                    NSLog("RUN INSERT")
                _ = try db.insert(sql: "INSERT INTO testtable (val) VALUES (1)", values: [])
                i = i + 1
                
            }
            if errorFound != nil {
                throw errorFound!
            }
                
            
            
            }())
        
        
    }
    
    func testSimultaneousOperationsShouldSucceedWithQueue() {
        
        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL
                );
            """)
            
            try conn.close()
            
            var keepInserting = true
            var errorFound:Error? = nil
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive).async {
                
                SQLiteConnectionQueue.withConnection(to: self.dbPath) { db in
                    try db.update(sql: "DELETE FROM testtable", values: [])
                }
                    .catch { error in
                        errorFound = error
                }
                    .always {
                        keepInserting = false
                }
                   
            }
            
            SQLiteConnectionQueue.withConnection(to: self.dbPath) { db in
                var i = 0
                while i < 10000 && keepInserting == true {
                    //                    NSLog("RUN INSERT")
                    _ = try db.insert(sql: "INSERT INTO testtable (val) VALUES (1)", values: [])
                    i = i + 1
                    
                }
                if errorFound != nil {
                    throw errorFound!
                }
                
            }
            .assertResolves()
            
            }())
        
        
    }
}
