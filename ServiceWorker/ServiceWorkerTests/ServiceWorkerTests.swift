import XCTest
@testable import ServiceWorker
import JavaScriptCore
import PromiseKit

class ServiceWorkerTests: XCTestCase {

    func testLoadContentFunction() {

        let sw = ServiceWorker.createTestWorker(id: name, content: "var testValue = 'hello';")

        return sw.evaluateScript("testValue")
            .then { (val: String?) -> Void in
                XCTAssertEqual(val, "hello")
            }
            .assertResolves()
    }

    func testThreadFreezing() {

        let sw = ServiceWorker.createTestWorker(id: name, content: "var testValue = 'hello';")

        sw.withJSContext { _ in

            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {

                Log.info?("signalling")
                semaphore.signal()
            })

            DispatchQueue.global().async {
                Promise(value: ())
                    .then {
                        Log.info?("doing this now")
                    }
            }

            Log.info?("waiting")
            semaphore.wait()
        }
        .assertResolves()
    }

    func testThreadFreezingInJS() {

        let sw = ServiceWorker.createTestWorker(id: name, content: "var testValue = 'hello';")

        let run: @convention(block) () -> Void = {
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {

                Promise(value: ())
                    .then { () -> Void in
                        Log.info?("signalling")
                        semaphore.signal()
                    }

            })
            Log.info?("wait")
            semaphore.wait()
        }

        sw.withJSContext { context in

            context.globalObject.setValue(run, forProperty: "testFunc")
        }
        .then {
            return sw.evaluateScript("testFunc()")
        }
        .then { () -> Void in
            // compiler needs this to be here
        }
        .assertResolves()
    }
}
