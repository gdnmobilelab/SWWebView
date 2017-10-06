import XCTest
@testable import ServiceWorker
import PromiseKit

class TimeoutTests: XCTestCase {

    func promiseDelay(delay: Double) -> Promise<Void> {
        return Promise<Void> { fulfill, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + (delay / 1000), execute: {
                fulfill(())
            })
        }
    }

    func testSetTimeout() {
        let sw = ServiceWorker.createTestWorker(id: name)

        sw.evaluateScript("""
            
            var ticks = 0;

            setTimeout(function() {
                ticks++;
            }, 10);

            setTimeout(function() {
                ticks++;
            }, 30);

        """)
            .then { _ in
                return self.promiseDelay(delay: 20)
            }
            .then {
                return sw.evaluateScript("ticks")
            }
            .then { (response: Int?) -> Void in

                XCTAssertEqual(response, 1)
            }
            .assertResolves()
    }

    //    func testSetTimeoutWithArguments() {
    //        let sw = ServiceWorker.createTestWorker(id: name)
    //
    //        sw.evaluateScript("""
    //            new Promise((fulfill,reject) => {
    //                setTimeout(function(one,two) {
    //                    fulfill([one,two])
    //                },10,"one","two")
    //            });
    //
    //        """)
    //            .then { jsVal in
    //                return JSPromise.fromJSValue(jsVal!)
    //            }
    //            .then { (response: [String]?) -> Void in
    //                XCTAssertEqual(response?[0], "one")
    //                XCTAssertEqual(response?[1], "two")
    //            }
    //
    //            .assertResolves()
    //    }

    func testSetInterval() {
        let sw = ServiceWorker.createTestWorker(id: name)

        sw.evaluateScript("""
            
            var ticks = 0;

            var interval = setInterval(function() {
                ticks++;
            }, 10);

        """)
            .then { _ in
                return self.promiseDelay(delay: 25)
            }
            .then {
                return sw.evaluateScript("clearInterval(interval); ticks")
            }
            .then { (response: Int?) -> Promise<Void> in
                XCTAssertEqual(response, 2)
                // check clearInterval works
                return self.promiseDelay(delay: 10)
            }
            .then {
                return sw.evaluateScript("ticks")
            }
            .then { (response: Int?) -> Void in
                XCTAssertEqual(response, 2)
            }
            .assertResolves()
    }
}
