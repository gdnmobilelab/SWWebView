//
//  Bootstrap.swift
//  ServiceWorkerContainerTests
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer
import XCTest
import ServiceWorker

class TestBootstrap: NSObject {

    override init() {
        super.init()
        
        Log.error = { NSLog($0) }
        Log.warn = { NSLog($0) }
        Log.info = { NSLog($0) }
        Log.debug = { NSLog($0) }
        
        do {
            CoreDatabase.dbDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testDB", isDirectory: true)
            if FileManager.default.fileExists(atPath: CoreDatabase.dbDirectory!.path) == false {
                try FileManager.default.createDirectory(at: CoreDatabase.dbDirectory!, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}
