//
//  ZZZZ_TestEndChecks.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 25/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
import PromiseKit
@testable import ServiceWorker

class ZZZZ_TestEndChecks: XCTestCase {
    
    func testShouldDeinitSuccessfully() {
        
        Promise(value:())
            .then { () -> Void in
                
                if ServiceWorkerExecutionEnvironment.allJSContexts.allObjects.count > 0 {
                    ServiceWorkerExecutionEnvironment.allJSContexts.allObjects.forEach { context in
                        NSLog("Still active context: \(context.name)")
                    }
                    throw ErrorMessage("Contexts still exist")
                }
                
                
                let worker = ServiceWorker.createTestWorker(id: self.name)
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
