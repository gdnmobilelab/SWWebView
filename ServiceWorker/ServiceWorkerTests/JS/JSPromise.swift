import XCTest
import JavaScriptCore
@testable import ServiceWorker
import PromiseKit

class JSPromiseTests: XCTestCase {

    func testFulfillPromise() {

        let sw = ServiceWorker.createTestWorker(id: name)
        var promise: JSContextPromise?

        sw.withJSContext { context in
            promise = try JSContextPromise(newPromiseInContext: context)
            context.globalObject.setValue(promise!.jsValue, forProperty: "testPromise")
        }.then {
            return sw.evaluateScript("""
                var testValue = 0;
                testPromise.then(function(newValue) {
                    testValue = newValue;
                })
            """)
        }.then { () -> Promise<Void> in
            promise!.fulfill(10)
            return sw.evaluateScript("testValue")
                .then { (returnVal: Int) -> Void in
                    XCTAssertEqual(returnVal, 10)
                }

        }.assertResolves()
    }

    //    func testRejectPromise() {
    //
    //        let context = JSContext()!
    //        let promise = JSPromise(context: context)
    //
    //        context.globalObject.setValue(promise.jsValue, forProperty: "testPromise")
    //
    //        context.evaluateScript("""
    //            var testValue = 0;
    //            testPromise.catch(function(errorValue) {
    //                testValue = errorValue.message;
    //            })
    //        """)
    //
    //        XCTAssert(context.objectForKeyedSubscript("testValue").toInt32() == 0)
    //        promise.reject(ErrorMessage("oh no"))
    //        let rejectValue = context
    //            .objectForKeyedSubscript("testValue")
    //            .toString()
    //        XCTAssert(rejectValue == "oh no")
    //    }
    //
    //    func testStaticResolvePromise() {
    //
    //        let context = JSContext()!
    //
    //        let promise = context.evaluateScript("Promise.resolve('testvalue')")!
    //        let expectResponse = expectation(description: "JS promise resolved")
    //
    //        JSPromise.resolve(promise) { err, val in
    //            XCTAssert(err == nil)
    //            XCTAssert(val!.toString() == "testvalue")
    //            expectResponse.fulfill()
    //        }
    //
    //        wait(for: [expectResponse], timeout: 1)
    //    }
    //
    //    func testStaticResolvePromiseThatRejects() {
    //
    //        let context = JSContext()!
    //
    //        let promise = context.evaluateScript("Promise.reject(new Error('oh no'))")!
    //        let expectResponse = expectation(description: "JS promise resolved")
    //
    //        JSPromise.resolve(promise) { err, _ in
    //            XCTAssertEqual((err as! ErrorMessage).message, "oh no")
    //            expectResponse.fulfill()
    //        }
    //
    //        wait(for: [expectResponse], timeout: 1)
    //    }
    //
    //    func testPromiseRejectionWithException() {
    //
    //        // We can also throw errors in a JSContext by setting the exception property
    //        // - just want to make sure that works correctly in the context of a promise
    //
    //        let context = JSContext()!
    //
    //        let testFunc: @convention(block) () -> Void = {
    //            context.exception = JSValue(newErrorFromMessage: "oh no", in: context)
    //        }
    //
    //        let jsfunc = context.evaluateScript("""
    //            (function(toRun) {
    //                return Promise.resolve()
    //                .then(function() {
    //                    toRun()
    //                    return true;
    //                })
    //            })
    //        """)
    //
    //        let promise = jsfunc!.call(withArguments: [unsafeBitCast(testFunc, to: AnyObject.self)])!
    //
    //        JSPromise.resolve(promise) { err, _ in
    //            XCTAssert((err as! ErrorMessage).message == "oh no")
    //        }
    //    }
}
