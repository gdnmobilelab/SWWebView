//
//  GlobalScopeTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 01/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import JavaScriptCore

class GlobalScopeTests: XCTestCase {

    func testEventListenersWork() {

        let sw = ServiceWorker.createTestWorker(id: name)
        sw.withJSContext { context in

            // should be accessible globally and in self.
            context.evaluateScript("""
                var fired = 0;
                self.addEventListener("test", function() {
                    fired++
                })

                addEventListener("test", function() {
                    fired++
                })
            """)
        }
        .then {
            let ev = ExtendableEvent(type: "test")
            return sw.dispatchEvent(ev)
        }
        .then {
            return sw.withJSContext { context in
                XCTAssertEqual(context.objectForKeyedSubscript("fired").toInt32(), 2)
            }
        }
        .assertResolves()
    }

    func testEventListenersHandleErrors() {

        let sw = ServiceWorker.createTestWorker(id: name)
        sw.withJSContext { context in

            // should be accessible globally and in self.
            context.evaluateScript("""
                self.addEventListener("activate", function () {
                    throw new Error("oh no")
                });
            """)
        }
        .then {
            let ev = ExtendableEvent(type: "activate")
            return sw.dispatchEvent(ev)
        }
        .then { () -> Int in
            return 1
        }
        .recover { error -> Int in
            XCTAssertEqual((error as! ErrorMessage).message, "Error: oh no")
            return 0
        }
        .then { val in
            XCTAssertEqual(val, 0)
        }

        .assertResolves()
    }

    func testAllEventFunctionsAreAdded() {
        let sw = ServiceWorker.createTestWorker(id: name)

        let keys = [
            "addEventListener", "removeEventListener", "dispatchEvent",
            "self.addEventListener", "self.removeEventListener", "self.dispatchEvent"
        ]

        sw.evaluateScript("[\(keys.joined(separator: ","))]")
            .then { vals -> Void in

                if let valArray = vals?.toArray() {

                    valArray.enumerated().forEach { arg in
                        let asJsVal = arg.element as? JSValue
                        XCTAssert(asJsVal == nil || asJsVal!.isUndefined == true, "Not found: " + keys[arg.offset])
                    }

                } else {
                    XCTFail("Could not get array, val: \(vals!.toString())")
                }
            }
            .assertResolves()
    }

    func testHasLocation() {

        let sw = ServiceWorker(id: name, url: URL(string: "http://www.example.com/sw.js")!, state: .activated, content: "")

        sw.evaluateScript("[self.location, location]")
            .then { val -> Void in
                let arr = val?.toArray() as? [WorkerLocation]
                XCTAssertNotNil(arr?[0])
                XCTAssertNotNil(arr?[1])
                XCTAssertEqual(arr?[0], arr?[1])
                XCTAssertEqual(arr?[0].href, "http://www.example.com/sw.js")
            }
            .assertResolves()
    }
}
