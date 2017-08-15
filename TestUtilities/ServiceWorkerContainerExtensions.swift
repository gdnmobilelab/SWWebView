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

extension CoreDatabase {
    static func clearForTests() {
        
        do {
            if FileManager.default.fileExists(atPath: self.dbPath!.path) {
                try FileManager.default.removeItem(at: self.dbPath!)
            }
            self.dbMigrationCheckDone = false
        } catch {
            XCTFail("\(error)")
        }
        
    }
}
