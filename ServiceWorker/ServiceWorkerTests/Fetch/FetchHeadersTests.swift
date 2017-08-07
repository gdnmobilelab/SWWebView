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
            {
                "Content-Type":["application/json"],
                "Cache-Control":["public","max-age=1"]
            }
        """
        
        var headers:FetchHeaders? = nil
        
        XCTAssertNoThrow(headers = try FetchHeaders.fromJSON(headersJSON))
        
    
        XCTAssert(headers!.get("Content-Type")! == "application/json")

        let cacheControl = headers!.getAll("Cache-Control")!

        XCTAssertEqual(cacheControl.count, 2)
        XCTAssertEqual(cacheControl[1], "max-age=1")
        
    }
}
