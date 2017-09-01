//
//  FetchHeadersTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker

class FetchHeadersTests: XCTestCase {

    func testShouldParseJSON() {

        let headersJSON = """
            [
                {"key":"Content-Type", "value": "application/json"},
                {"key":"Cache-Control", "value": "public"},
                {"key":"Cache-Control", "value": "max-age=1"}
            ]
        """

        var headers: FetchHeaders?

        XCTAssertNoThrow(headers = try FetchHeaders.fromJSON(headersJSON))

        XCTAssert(headers!.get("Content-Type")! == "application/json")

        let cacheControl = headers!.getAll("Cache-Control")

        XCTAssertEqual(cacheControl.count, 2)
        XCTAssertEqual(cacheControl[1], "max-age=1")
    }
    
    func testShouldAppendGetAndDelete() {
        
        let fh = FetchHeaders()
        fh.append("Test", "Value")
        
        XCTAssertEqual(fh.get("Test"), "Value")
        
        fh.append("Test","Value2")
        
        XCTAssertEqual(fh.get("Test"), "Value,Value2")
        
        XCTAssertEqual(fh.getAll("test"), ["Value", "Value2"])
        
        fh.set("test", "NEW VALUE")
        
        XCTAssertEqual(fh.get("test"), "NEW VALUE")
        
        fh.delete("test")
        
        XCTAssertNil(fh.get("Test"))
    }

}
