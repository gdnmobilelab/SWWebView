//
//  URLTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 25/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker

class URLTests: XCTestCase {
    
    
    func testURLExists() {
        
        let sw = ServiceWorker.createTestWorker()
        
        sw.evaluateScript("typeof(URL) != 'undefined' && self.URL == URL")
            .then { val in
                
            XCTAssertEqual(val!.toBool(), true)
        }
        .assertResolves()
    }
    
    func testURLHashExists() {
        
        let sw = ServiceWorker.createTestWorker()
        
        sw.evaluateScript("new URL('http://www.example.com/#test').hash")
            .then { val in
                
                XCTAssertEqual(val!.toString(), "#test")
            }
            .assertResolves()
    }
    
    func testURLHashCanBeSet() {
        
        let sw = ServiceWorker.createTestWorker()
        
        sw.evaluateScript("let url =new URL('http://www.example.com/#test'); url.hash = 'test2'; url.hash")
            .then { val in
                
                XCTAssertEqual(val!.toString(), "#test2")
            }
            .assertResolves()
    }
    
   
    
}
