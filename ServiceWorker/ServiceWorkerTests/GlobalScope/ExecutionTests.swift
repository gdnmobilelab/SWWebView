import XCTest
@testable import ServiceWorker

class ExecutionTests: XCTestCase {

    func testAsyncDispatch() {
        // Trying to work out why variables sometimes don't exist

        let worker = ServiceWorker.createTestWorker(id: name, content: """
            var test = "hello"
        """)

        worker.evaluateScript("test")
            .then { jsVal -> Void in
                XCTAssertEqual(jsVal!.toString(), "hello")
            }
            .assertResolves()
    }
}
