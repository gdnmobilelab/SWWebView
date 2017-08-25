//
//  FetchRequestTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 25/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker

class FetchRequestTests: XCTestCase {

    func testShouldConstructAbsoluteURL() {

        let sw = ServiceWorker(id: "TEST", url: URL(string: "http://www.example.com/sw.js")!, state: .activated, content: "")

        sw.evaluateScript("new Request('./test')")
            .then { val -> Void in
                let req = val?.toObjectOf(FetchRequest.self) as? FetchRequest
                XCTAssertNotNil(req)
                XCTAssertEqual(req?.url.absoluteString, "http://www.example.com/test")
            }
            .assertResolves()
    }
}
