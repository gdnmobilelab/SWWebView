import XCTest
@testable import ServiceWorker
import GCDWebServers
import Gzip
import JavaScriptCore
import PromiseKit

class FetchPerformance: XCTestCase {

    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        TestWeb.createServer()

        let testData = Data(count: 327_680)

        TestWeb.server!.addHandler(forMethod: "GET", path: "/data", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(data: testData, contentType: "anything")
            return res
        }
    }

    override func tearDown() {
        TestWeb.destroyServer()
        super.tearDown()
    }

    func testNative() {
        // This is an example of a performance test case.
        self.measure {

            let data = try! Data(contentsOf: TestWeb.serverURL.appendingPathComponent("data"))
        }
    }

    func testFetch() {
        self.measure {
            FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("data"))
                .then { res in
                    res.data()
                }
                .assertResolves()
        }
    }
}
