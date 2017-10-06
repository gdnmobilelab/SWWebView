import XCTest
@testable import ServiceWorker
import GCDWebServers
import Gzip
import PromiseKit

class FetchOperationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        TestWeb.createServer()
    }

    override func tearDown() {
        TestWeb.destroyServer()
        super.tearDown()
    }

    func testSimpleFetch() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(jsonObject: [
                "blah": "value"
            ])
            res!.statusCode = 201
            res!.setValue("TEST-VALUE", forAdditionalHeader: "X-Test-Header")
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        FetchSession.default.fetch(request)
            .then { response -> Void in
                XCTAssertEqual(response.status, 201)
                XCTAssertEqual(response.headers.get("X-Test-Header"), "TEST-VALUE")
            }
            .assertResolves()
    }

    func testSimpleFetchBody() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(jsonObject: [
                "blah": "value"
            ])
            res!.statusCode = 201
            res!.setValue("TEST-VALUE", forAdditionalHeader: "X-Test-Header")
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        FetchSession.default.fetch(request)
            .then { response -> Promise<Any?> in
                return response.json()
            }
            .then { obj -> Void in
                let json = obj as! [String: String]
                XCTAssertEqual(json["blah"], "value")
            }
            .assertResolves()
    }

    func testMultipleFetches() {

        // trying to work out what's going on with some streaming bug

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { _, complete in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                complete(GCDWebServerDataResponse(text: "this is some text"))
            })
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test2.txt", request: GCDWebServerRequest.self) { _, complete in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                complete(GCDWebServerDataResponse(text: "this is some text two"))
            })
        }

        when(fulfilled: [
            FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt")).then { $0.text() },
            FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test2.txt")).then { $0.text() }
        ])
            .then { responses -> Void in
                XCTAssertEqual(responses[0], "this is some text")
                XCTAssertEqual(responses[1], "this is some text two")
            }
            .assertResolves()

        when(fulfilled: [
            FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test2.txt")).then { $0.text() },
            FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt")).then { $0.text() }
        ])
            .then { responses -> Void in
                XCTAssertEqual(responses[0], "this is some text two")
                XCTAssertEqual(responses[1], "this is some text")
            }
            .assertResolves()
    }

    func testFailedFetch() {

        FetchSession.default.fetch(URL(string: "http://localhost:23423")!)
            .assertRejects()
    }

    fileprivate func setupRedirectURLs() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 201
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/redirect-me", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in

            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 301
            res!.setValue("/test.txt", forAdditionalHeader: "Location")
            return res
        }
    }

    func testRedirectFetch() {

        self.setupRedirectURLs()

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/redirect-me"))

        FetchSession.default.fetch(request)
            .then { response -> Void in
                XCTAssertEqual(response.status, 201)

                XCTAssertEqual(response.url!.absoluteString, TestWeb.serverURL.appendingPathComponent("/test.txt").absoluteString)
            }
            .assertResolves()
    }

    func testRedirectNoFollow() {
        self.setupRedirectURLs()

        let expectNotRedirect = expectation(description: "Fetch call does not redirect")

        let noRedirectRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/redirect-me"))
        noRedirectRequest.redirect = .Manual

        FetchSession.default.fetch(noRedirectRequest)
            .then { response -> Void in
                XCTAssert(response.status == 301, "Should be a 301 status")
                XCTAssert(response.headers.get("Location") == "/test.txt", "URL should be correct")
                XCTAssert(response.url!.absoluteString == TestWeb.serverURL.appendingPathComponent("/redirect-me").absoluteString)
                expectNotRedirect.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [expectNotRedirect], timeout: 10)
    }

    func testRedirectError() {
        self.setupRedirectURLs()

        let errorRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/redirect-me"))
        errorRequest.redirect = .Error

        FetchSession.default.fetch(errorRequest)
            .assertRejects()
    }

    func testFetchRequestBody() {

        let expectResponse = expectation(description: "Request body is received")

        TestWeb.server!.addHandler(forMethod: "POST", path: "/post", request: GCDWebServerDataRequest.self) { (request) -> GCDWebServerResponse? in
            let dataReq = request as! GCDWebServerDataRequest

            let str = String(data: dataReq.data, encoding: String.Encoding.utf8)
            XCTAssert(str == "TEST STRING")

            let res = GCDWebServerResponse(statusCode: 200)
            expectResponse.fulfill()
            return res
        }

        let postRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/post"))
        postRequest.body = "TEST STRING".data(using: String.Encoding.utf8)
        postRequest.method = "POST"

        let fulfilled = expectation(description: "The promise returned")
        FetchSession.default.fetch(postRequest)
            .then { _ in
                fulfilled.fulfill()
            }
            .catch { error in
                XCTFail("\(error)")
            }

        wait(for: [fulfilled, expectResponse], timeout: 1)
    }

    func atestJSFetch() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
        }

        let sw = TestWorker(id: "TEST", state: .activated, url: TestWeb.serverURL, content: "")

        sw.evaluateScript("""
            fetch('\(TestWeb.serverURL.appendingPathComponent("/test.txt").absoluteString)')
            .then(function(res) {
            
            function valOrNo(val) {
                if (typeof val == "undefined") {
                    return -1;
                } else {
                    return 1;
                }
            }
            
            return {
                status: valOrNo(res.status),
                ok: valOrNo(res.ok),
                redirected: valOrNo(res.redirected),
                statusText: valOrNo(res.statusText),
                type: valOrNo(res.type),
                url: valOrNo(res.url),
                bodyUsed: valOrNo(res.bodyUsed),
                json: valOrNo(res.json),
                text: valOrNo(res.text)
            }
            })
        """)
            .then { (val: JSContextPromise) in
                return val.resolve()
            }.then { (obj: [String: Int]) -> Void in

                for (key, val) in obj {
                    XCTAssert(val != -1, "Property \(key) should exist")
                }
            }
            .assertResolves()
    }
}
