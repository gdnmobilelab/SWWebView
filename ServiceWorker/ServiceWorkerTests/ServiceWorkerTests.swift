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

    func atestThreadFreezing() {

        let sw = ServiceWorker.createTestWorker(id: name, content: "var testValue = 'hello';")

        sw.withJSContext { _ in

            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {

                NSLog("signalling")
                semaphore.signal()
            })

            DispatchQueue.global().async {
                Promise(value: ())
                    .then {
                        NSLog("doing this now")
                    }
            }

            NSLog("waiting")
            semaphore.wait()
        }
        .assertResolves()
    }

    func atestThreadFreezingInJS() {

        let sw = ServiceWorker.createTestWorker(id: name, content: "var testValue = 'hello';")

        let run: @convention(block) () -> Void = {
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {

                Promise(value: ())
                    .then { () -> Void in
                        NSLog("signalling")
                        semaphore.signal()
                    }

            })
            NSLog("wait")
            semaphore.wait()
        }

        sw.withJSContext { context in

            context.globalObject.setValue(run, forProperty: "testFunc")
        }
        .then {
            return sw.evaluateScript("testFunc()")
        }
        .assertResolves()
    }
}
