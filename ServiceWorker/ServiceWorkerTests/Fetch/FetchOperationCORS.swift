import XCTest
@testable import ServiceWorker
import GCDWebServers
import JavaScriptCore

class FetchOperationCORSTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        TestWeb.createServer()
    }

    override func tearDown() {
        TestWeb.destroyServer()
        super.tearDown()
    }

    func testDisallowedCORSNoOption() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .assertRejects()
    }

    func testDisallowedCORSOptionNoOrigin() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("http://also-not-localhost", forAdditionalHeader: "Access-Control-Allow-Origin")
            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call fails")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { _ in
                XCTFail("This should not succeed")
            }
            .catch { _ in
                expect.fulfill()
            }

        wait(for: [expect, serverExpectation], timeout: 1)
    }

    func testAllowedCORSOptionWithSpecificOrigin() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("http://not-localhost", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")

            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call works")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { response -> Void in
                XCTAssert(response.responseType == ResponseType.CORS)
                expect.fulfill()
            }
            .catch { _ in
                XCTFail()
            }

        wait(for: [expect, serverExpectation], timeout: 1)
    }

    func testAllowedCORSOptionWithWildcardOrigin() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")

            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call fails")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { response -> Void in
                XCTAssert(response.responseType == ResponseType.CORS)
                expect.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [expect, serverExpectation], timeout: 1)
    }

    func testDisallowedCORSOptionMissingMethod() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("http://not-localhost", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("POST", forAdditionalHeader: "Access-Control-Allow-Methods")
            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call fails")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { _ in
                XCTFail("Should not succeed")
            }
            .catch { _ in
                expect.fulfill()
            }

        wait(for: [expect, serverExpectation], timeout: 1)
    }

    func testAllowedCORSOptionWithMethod() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("http://not-localhost", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("POST, GET", forAdditionalHeader: "Access-Control-Allow-Methods")
            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call works")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { response -> Void in
                XCTAssert(response.responseType == ResponseType.CORS)
                expect.fulfill()
            }
            .assertResolves()

        wait(for: [expect, serverExpectation], timeout: 1)
    }

    func testMissingHeaderWhenNotAllowed() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")
            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "blah")!
            res.setValue("TESTVALUE", forAdditionalHeader: "X-Additional-Header")
            res.setValue("TESTVALUE2", forAdditionalHeader: "X-Header-Two")
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call is missing header")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { response -> Void in
                XCTAssert(response.responseType == ResponseType.CORS)
                XCTAssertNil(response.headers.get("X-Additional-Header"))
                XCTAssertNil(response.headers.get("X-Header-Two"))
                expect.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [expect, serverExpectation], timeout: 1)
    }

    func testHasHeaderWhenAllowed() {

        let serverExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")

            res.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")

            serverExpectation.fulfill()
            return res
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "blah")!
            res.setValue("TESTVALUE", forAdditionalHeader: "X-Additional-Header")
            res.setValue("TESTVALUE2", forAdditionalHeader: "X-Header-Two")
            res.setValue("X-Additional-Header, X-Header-Two", forAdditionalHeader: "Access-Control-Expose-Headers")
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let fetchExpectation = expectation(description: "Fetch call should return")

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { response -> Void in
                XCTAssert(response.responseType == ResponseType.CORS)
                XCTAssertEqual(response.headers.get("X-Additional-Header"), "TESTVALUE")
                XCTAssertEqual(response.headers.get("X-Header-Two"), "TESTVALUE2")
                fetchExpectation.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [serverExpectation, fetchExpectation], timeout: 1)
    }

    func testFiltersRequestHeadersWhenNoAllowHeaderIsProvided() {

        let optionsExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")

            optionsExpectation.fulfill()
            return res
        }

        let getExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in

            XCTAssertNil(request.headers["X-Custom-Header"])

            getExpectation.fulfill()

            let res = GCDWebServerDataResponse(text: "blah")!

            return res
        }

        let fetchRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let fetchExpectation = expectation(description: "Fetch call should return")

        fetchRequest.headers.set("x-custom-header", "test-value")

        FetchSession.default.fetch(fetchRequest, fromOrigin: URL(string: "http://not-localhost"))
            .then { _ -> Void in
                fetchExpectation.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [optionsExpectation, getExpectation, fetchExpectation], timeout: 1)
    }

    func testKeepsRequestHeadersWhenAllowHeaderIsProvided() {

        let optionsExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "OPTIONS", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerResponse()
            res.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            res.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")
            res.setValue("X-Custom-Header", forAdditionalHeader: "Access-Control-Allow-Headers")
            optionsExpectation.fulfill()
            return res
        }

        let getExpectation = expectation(description: "Fetch call should hit OPTIONS")

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in

            XCTAssertEqual(request.headers["x-custom-header"] as? String, "test-value")

            getExpectation.fulfill()

            let res = GCDWebServerDataResponse(text: "blah")!

            return res
        }

        let fetchRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let fetchExpectation = expectation(description: "Fetch call should return")

        fetchRequest.headers.set("X-Custom-Header", "test-value")

        FetchSession.default.fetch(fetchRequest, fromOrigin: URL(string: "http://not-localhost"))
            .then { _ -> Void in
                fetchExpectation.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [optionsExpectation, getExpectation, fetchExpectation], timeout: 10)
    }

    func testAllowsOpaqueCORSResponse() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(text: "blah")
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))
        request.mode = .NoCORS

        FetchSession.default.fetch(request, fromOrigin: URL(string: "http://not-localhost"))
            .then { response in
                XCTAssert(response.responseType == .Opaque)
                return response.text()
            }
            .then { text in
                XCTAssertEqual(text, "")
            }
            .assertResolves()
    }

    func testReturnsBasicResponseWhenSameDomain() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "blah")!
            res.setValue("TEST", forAdditionalHeader: "X-Custom-Header")
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))
        request.mode = .NoCORS

        let expect = expectation(description: "Fetch call works")

        FetchSession.default.fetch(request, fromOrigin: TestWeb.serverURL)
            .then { response -> Void in
                XCTAssertEqual(response.headers.get("X-Custom-Header"), "TEST")
                XCTAssert(response.responseType == .Basic)
                expect.fulfill()
            }.catch { _ in
                XCTFail()
            }

        wait(for: [expect], timeout: 1)
    }
}
