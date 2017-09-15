//
//  PerformanceTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 15/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker

class PerformanceTests: XCTestCase {

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            let testSw = ServiceWorker.createTestWorker(id: "PERFORMANCE")
            testSw.evaluateScript("console.log('hi')")
                .assertResolves()
        }
    }
}
