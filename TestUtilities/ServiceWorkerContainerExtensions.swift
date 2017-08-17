//
//  ServiceWorkerContainerExtensions.swift
//  ServiceWorkerContainerTests
//
//  Created by alastair.coote on 08/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
@testable import ServiceWorkerContainer
import XCTest
import ServiceWorker

extension CoreDatabase {
    static func clearForTests() {
        
        do {
            try SQLiteConnection.inConnection(self.dbPath!) {db in
                    try db.exec(sql: """
                PRAGMA writable_schema = 1;
                delete from sqlite_master where type in ('table', 'index', 'trigger');
                PRAGMA writable_schema = 0;
                VACUUM;
            """)
                }
          
            
           
            self.dbMigrationCheckDone = false
        } catch {
            XCTFail("\(error)")
        }
        
    }
}
