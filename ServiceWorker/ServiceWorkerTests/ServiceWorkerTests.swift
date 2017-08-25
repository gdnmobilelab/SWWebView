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

        let sw = ServiceWorker.createTestWorker(content: "var testValue = 'hello';")

        return sw.evaluateScript("testValue")
            .then { val in
                XCTAssertEqual(val!.toString(), "hello")
            }
            .assertResolves()
    }

    func testLoadContentDirectly() {

        let sw = ServiceWorker.createTestWorker(content: "var testValue = 'hello';")

        sw.evaluateScript("testValue")
            .then { jsVal in
                XCTAssertEqual(jsVal!.toString(), "hello")
            }
            .assertResolves()
    }
    
    func doNottestShouldDeinitSuccessfully() {
        
        Promise(value:())
            .then { () -> Void in
            let worker = ServiceWorker.createTestWorker()
             _ =   worker.getExecutionEnvironment()
                 XCTAssertEqual(ServiceWorkerExecutionEnvironment.allJSContexts.allObjects.count, 1)
            }.then { _ -> Promise<Void> in
                
                return Promise<Void> { fulfill, reject in
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        NSLog("Performing check")
                        XCTAssertEqual(ServiceWorkerExecutionEnvironment.allJSContexts.allObjects.count, 0)
                        fulfill(())
                    })
                    
                }
                
               
        }
        .assertResolves()
        
    }
}
