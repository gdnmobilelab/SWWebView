//
//  TimeoutTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 18/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker

class TimeoutTests: XCTestCase {

    func testSetTimeout() {
        let sw = ServiceWorker.createTestWorker(id: name)

        sw.evaluateScript("""
            new Promise((fulfill, reject) => {
                setTimeout(fulfill, 20)
            })
        """)
            .then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }
            .assertResolves()
    }
}
