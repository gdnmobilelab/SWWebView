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

    override func tearDown() {
        ServiceWorkerTestDelegate.reset()
    }

    func testImportingAScript() {

        let sw = ServiceWorker.createTestWorker(id: name)

        ServiceWorkerTestDelegate.importScripts = { urls, _, cb in
            XCTAssertEqual(urls[0].absoluteString, "http://www.example.com/test.js")
            cb(nil, ["testValue = 'hello';"])
        }

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }

    func testImportingMultipleScripts() {

        let sw = ServiceWorker.createTestWorker(id: name)

        ServiceWorkerTestDelegate.importScripts = { urls, _, cb in
            XCTAssertEqual(urls[0].absoluteString, "http://www.example.com/test.js")
            XCTAssertEqual(urls[1].absoluteString, "http://www.example.com/test2.js")
            cb(nil, ["testValue = 'hello';", "testValue = 'hello2';"])
        }

        sw.evaluateScript("importScripts(['test.js', 'test2.js']); testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello2")
            }
            .assertResolves()
    }

    func testImportingWithAsyncOperation() {

        let sw = ServiceWorker.createTestWorker(id: name)

        ServiceWorkerTestDelegate.importScripts = { _, _, cb in

            DispatchQueue.global().async {
                cb(nil, ["testValue = 'hello';"])
            }
        }

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }
}
