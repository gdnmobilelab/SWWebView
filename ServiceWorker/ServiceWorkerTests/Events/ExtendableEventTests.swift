import XCTest
import JavaScriptCore
@testable import ServiceWorker
import PromiseKit

class ExtendableEventTests: XCTestCase {

    func testExtendingAnEvent() {

        let sw = ServiceWorker.createTestWorker(id: name)

        sw.withJSContext { context in
            let ev = ExtendableEvent(type: "test")
            context.globalObject.setValue(ev, forProperty: "testEvent")
        }
        .then {
            sw.evaluateScript("""
                var testResult = false
                testEvent.waitUntil(new Promise(function(fulfill,reject) {
                    testResult = true
                    fulfill()
                }));
                 testEvent;
            """)
        }

        .then { (ev: ExtendableEvent) in
            ev.resolve(in: sw)
        }
        .then {
            return sw.evaluateScript("testResult")
        }
        .then { (result: Bool) in
            XCTAssertEqual(result, true)
        }

        .assertResolves()
    }

    func testPromiseRejection() {

        let sw = ServiceWorker.createTestWorker(id: name)

        sw.withJSContext { context in
            let ev = ExtendableEvent(type: "test")
            context.globalObject.setValue(ev, forProperty: "testEvent")
        }
        .then {
            sw.evaluateScript("""
                testEvent.waitUntil(new Promise(function(fulfill,reject) {
                    reject(new Error("failure"))
                }))
                testEvent;
            """)
        }

        .then { (ev: ExtendableEvent) in
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

        sw.withJSContext { context in
            let ev = ExtendableEvent(type: "test")
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
                }));
                testEvent;
            """)
        }

        .then { (ev: ExtendableEvent) in
            ev.resolve(in: sw)
        }
        .then {
            return sw.evaluateScript("resultArray")
        }
        .then { (results: [Int]?) -> Void in

            XCTAssertEqual(results?.count, 2)
            XCTAssertEqual(results?[0] as? Int, 1)
            XCTAssertEqual(results?[1] as? Int, 2)
        }

        .assertResolves()
    }

    func testNoPromises() {
        let sw = ServiceWorker.createTestWorker(id: name)

        let ev = ExtendableEvent(type: "test")
        ev.resolve(in: sw)
            .then { () -> Void in
                // compiler requires this
            }
            .assertResolves()
    }
}
