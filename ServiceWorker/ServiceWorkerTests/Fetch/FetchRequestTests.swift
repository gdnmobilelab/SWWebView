import XCTest
@testable import ServiceWorker

class FetchRequestTests: XCTestCase {

    func testShouldConstructAbsoluteURL() {

        let sw = TestWorker(id: "TEST", state: .activated, url: URL(string: "http://www.example.com/sw.js")!, content: "")

        sw.evaluateScript("new Request('./test')")
            .then { (req: FetchRequest?) -> Void in
                XCTAssertNotNil(req)
                XCTAssertEqual(req?.url.absoluteString, "http://www.example.com/test")
            }
            .assertResolves()
    }
}
