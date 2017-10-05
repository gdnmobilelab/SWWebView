import XCTest
import PromiseKit
@testable import ServiceWorker
import JavaScriptCore

class ZZZZ_TestEndChecks: XCTestCase {

    /// A wrap-up test we always want to run last, that double-checks all of our JSContexts
    /// have been garbage collected. If they haven't, it means we have a memory leak somewhere.
    func testShouldDeinitSuccessfully() {

        let queues = ServiceWorkerExecutionEnvironment.contextDispatchQueues

        Promise(value: ())
            .then { () -> Void in

                if queues.count > 0 {

                    let allContexts = ServiceWorkerExecutionEnvironment.contextDispatchQueues.keyEnumerator().allObjects as! [JSContext]

                    allContexts.forEach { context in
                        NSLog("Still active context: \(context.name)")
                    }

                    throw ErrorMessage("Contexts still exist")
                }

                let worker = ServiceWorker.createTestWorker(id: self.name)
                _ = worker.getExecutionEnvironment()

                XCTAssertEqual(queues.count, 1)
            }.then { _ -> Promise<Void> in

                Promise<Void> { fulfill, _ in

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        NSLog("Performing check")

                        queues.objectEnumerator()!.forEach { _ in
                            NSLog("valll")
                        }

                        queues.keyEnumerator().forEach { key in
                            let val = queues.object(forKey: key as! JSContext)
                            NSLog("WHAAT")
                        }

                        XCTAssertEqual(ServiceWorkerExecutionEnvironment.contextDispatchQueues.count, 0)
                        fulfill(())
                    })
                }
            }
            .assertResolves()
    }
}
