//
//  ServiceWorkerTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 14/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import JavaScriptCore
import PromiseKit

class ServiceWorkerTests: XCTestCase {

    func testLoadContentFunction() {

        let sw = ServiceWorker.createTestWorker(id: self.name, content: "var testValue = 'hello';")

        return sw.evaluateScript("testValue")
            .then { val in
                XCTAssertEqual(val!.toString(), "hello")
            }
            .assertResolves()
    }

    func testLoadContentDirectly() {

        let sw = ServiceWorker.createTestWorker(id: self.name, content: "var testValue = 'hello';")

        sw.evaluateScript("testValue")
            .then { jsVal in
                XCTAssertEqual(jsVal!.toString(), "hello")
            }
            .assertResolves()
    }
}
