//
//  ExtendableEventTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 25/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
import JavaScriptCore
@testable import ServiceWorker
import PromiseKit

class ExtendableEventTests: XCTestCase {

    func testExtendingAnEvent() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let ev = ExtendableEvent(type: "test")

        return sw.withJSContext { context in
            context.globalObject.setValue(ev, forProperty: "testEvent")
        }
        .then {
            sw.evaluateScript("""
                var testResult = false
                testEvent.waitUntil(new Promise(function(fulfill,reject) {
                    testResult = true
                    fulfill()
                }))
            """)
        }

        .then { _ in
            ev.resolve(in: sw)
        }
        .then {

            sw.withJSContext { context in
                XCTAssertEqual(context.objectForKeyedSubscript("testResult").toBool(), true)
            }
        }

        .assertResolves()
    }

    func testPromiseRejection() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let ev = ExtendableEvent(type: "test")

        return sw.withJSContext { context in
            context.globalObject.setValue(ev, forProperty: "testEvent")
        }
        .then {
            sw.evaluateScript("""
                testEvent.waitUntil(new Promise(function(fulfill,reject) {
                    reject(new Error("failure"))
                }))
            """)
        }

        .then { _ in
            ev.resolve(in: sw)
        }
        .then {
            XCTFail("Promise should not resolve")
        }
        .recover { error in
            XCTAssertEqual(String(describing: error), "failure")
        }

        .assertResolves()
    }

    func testMultiplePromises() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let ev = ExtendableEvent(type: "test")

        return sw.withJSContext { context in
            context.globalObject.setValue(ev, forProperty: "testEvent")
        }
        .then {
            sw.evaluateScript("""
                var resultArray = [];
                testEvent.waitUntil(new Promise(function(fulfill,reject) {
                    resultArray.push(1);
                    fulfill();
                }))
                testEvent.waitUntil(new Promise(function(fulfill,reject) {
                    setTimeout(function() {
                        resultArray.push(2);
                        fulfill();
                    },10);
                }))
            """)
        }

        .then { _ in
            ev.resolve(in: sw)
        }
        .then {

            sw.withJSContext { context in
                let results = context.objectForKeyedSubscript("resultArray").toArray()

                XCTAssertEqual(results?.count, 2)
                XCTAssertEqual(results?[0] as? Int, 1)
                XCTAssertEqual(results?[1] as? Int, 2)
            }
        }

        .assertResolves()
    }

    func testNoPromises() {
        let sw = ServiceWorker.createTestWorker(id: name)

        let ev = ExtendableEvent(type: "test")

        return sw.withJSContext { context in

            context.evaluateScript("self.addEventListener('test', function() {});")
        }
        .then {
            sw.dispatchEvent(ev)
        }
        .then {
            ev.resolve(in: sw)
        }
        .assertResolves()
    }
}
