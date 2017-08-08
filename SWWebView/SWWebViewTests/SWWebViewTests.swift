//
//  SWWebViewTests.swift
//  SWWebViewTests
//
//  Created by alastair.coote on 07/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import SWWebView
import WebKit

class SWWebViewTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreate() {
        
        let sw = SWWebView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        sw.loadHTMLString("<html></html>", baseURL: nil)
        NSLog("wuh")
        
        let exp = expectation(description: "This is a test")
        
        wait(for: [exp], timeout: 100)
    }
    

    
}
