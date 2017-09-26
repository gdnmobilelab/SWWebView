import XCTest
@testable import ServiceWorker

class TimeoutTests: XCTestCase {

    func testSetTimeout() {
        let sw = ServiceWorker.createTestWorker(id: name)

        sw.evaluateScript("""
            new Promise((fulfill, reject) => {
                setTimeout(fulfill, 20)
            })
        """)
            .then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }
            .assertResolves()
    }
}
