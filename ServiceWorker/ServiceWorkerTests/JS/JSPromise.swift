//
//  JSPromise.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 23/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
import JavaScriptCore
@testable import ServiceWorker

class JSPromiseTests: XCTestCase {

    func testFulfillPromise() {

        let context = JSContext()!
        let promise = JSPromise(context: context)

        context.globalObject.setValue(promise.jsValue, forProperty: "testPromise")

        context.evaluateScript("""
            var testValue = 0;
            testPromise.then(function(newValue) {
                testValue = newValue;
            })
        """)

        XCTAssert(context.objectForKeyedSubscript("testValue").toInt32() == 0)
        promise.fulfill(10)
        XCTAssert(context.objectForKeyedSubscript("testValue").toInt32() == 10)
    }

    func testRejectPromise() {

        let context = JSContext()!
        let promise = JSPromise(context: context)

        context.globalObject.setValue(promise.jsValue, forProperty: "testPromise")

        context.evaluateScript("""
            var testValue = 0;
            testPromise.catch(function(errorValue) {
                testValue = errorValue.message;
            })
        """)

        XCTAssert(context.objectForKeyedSubscript("testValue").toInt32() == 0)
        promise.reject(ErrorMessage("oh no"))
        let rejectValue = context
            .objectForKeyedSubscript("testValue")
            .toString()
        XCTAssert(rejectValue == "oh no")
    }

    func testStaticResolvePromise() {

        let context = JSContext()!

        let promise = context.evaluateScript("Promise.resolve('testvalue')")!
        let expectResponse = expectation(description: "JS promise resolved")

        JSPromise.resolve(promise) { err, val in
            XCTAssert(err == nil)
            XCTAssert(val!.toString() == "testvalue")
            expectResponse.fulfill()
        }

        wait(for: [expectResponse], timeout: 1)
    }

    func testStaticResolvePromiseThatRejects() {

        let context = JSContext()!

        let promise = context.evaluateScript("Promise.reject(new Error('oh no'))")!
        let expectResponse = expectation(description: "JS promise resolved")

        JSPromise.resolve(promise) { err, _ in
            XCTAssertEqual((err as! ErrorMessage).message, "oh no")
            expectResponse.fulfill()
        }

        wait(for: [expectResponse], timeout: 1)
    }

    func testPromiseRejectionWithException() {

        // We can also throw errors in a JSContext by setting the exception property
        // - just want to make sure that works correctly in the context of a promise

        let context = JSContext()!

        let testFunc: @convention(block) () -> Void = {
            context.exception = JSValue(newErrorFromMessage: "oh no", in: context)
        }

        let jsfunc = context.evaluateScript("""
            (function(toRun) {
                return Promise.resolve()
                .then(function() {
                    toRun()
                    return true;
                })
            })
        """)

        let promise = jsfunc!.call(withArguments: [unsafeBitCast(testFunc, to: AnyObject.self)])!

        JSPromise.resolve(promise) { err, _ in
            XCTAssert((err as! ErrorMessage).message == "oh no")
        }
    }
}
