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
    
    func testWKWebViewStuff() {
        
        let wk = WKWebView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
//        wk.loadHTMLString("", baseURL: URL(string: "http://www.example.com")!)
        wk.evaluateJavaScript("test") { (resp, err) in
            NSLog("woah")
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
