//
//  ImportScriptsTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 24/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import JavaScriptCore

class ImportScriptsTests: XCTestCase {

    func testImportingAScript() {

        let sw = ServiceWorker.createTestWorker()

        sw.importScripts = { _, scripts in
            XCTAssertEqual(scripts[0].absoluteString, "http://www.example.com/test.js")
            return ["testValue = 'hello';"]
        }

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }

    func testImportingMultipleScripts() {

        let sw = ServiceWorker.createTestWorker()

        sw.importScripts = { _, scripts in
            XCTAssertEqual(scripts[0].absoluteString, "http://www.example.com/test.js")
            XCTAssertEqual(scripts[1].absoluteString, "http://www.example.com/test2.js")
            return ["testValue = 'hello';", "testValue = 'hello2';"]
        }

        sw.evaluateScript("importScripts(['test.js', 'test2.js']); testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello2")
            }
            .assertResolves()
    }

    func testImportingWithBlockingSyncOperation() {

        let sw = ServiceWorker.createTestWorker()

        sw.importScripts = { _, scripts in
            XCTAssertEqual(scripts[0].absoluteString, "http://www.example.com/test.js")

            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(1)) {
                semaphore.signal()
            }

            _ = semaphore.wait(timeout: .distantFuture)

            return ["testValue = 'hello';"]
        }

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }
}
