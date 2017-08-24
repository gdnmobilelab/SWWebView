//
//  ExecutionTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 28/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker

class ExecutionTests: XCTestCase {

    func testAsyncDispatch() {
        // Trying to work out why variables sometimes don't exist

        let worker = ServiceWorker.createTestWorker(content: """
            var test = "hello"
        """)

        worker.evaluateScript("test")
            .then { jsVal -> Void in
                XCTAssertEqual(jsVal!.toString(), "hello")
            }
            .assertResolves()
    }
}
