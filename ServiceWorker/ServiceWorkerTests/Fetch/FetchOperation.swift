//
//  FetchOperation.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 14/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import GCDWebServers
import Gzip
import JavaScriptCore
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
                "blah": "value",
            ])
            res!.statusCode = 201
            res!.setValue("TEST-VALUE", forAdditionalHeader: "X-Test-Header")
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test.txt"))

        let expect = expectation(description: "Fetch call returns")

        FetchOperation.fetch(request) { _, response in
            XCTAssert(response != nil)
            XCTAssertEqual(response!.status, 201)
            XCTAssertEqual(response!.headers.get("X-Test-Header"), "TEST-VALUE")
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)
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
            FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt")).then { $0.text() },
            FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test2.txt")).then { $0.text() },
        ])
            .then { responses -> Void in
                XCTAssertEqual(responses[0], "this is some text")
                XCTAssertEqual(responses[1], "this is some text two")
            }
            .assertResolves()

        when(fulfilled: [
            FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test2.txt")).then { $0.text() },
            FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt")).then { $0.text() },
        ])
            .then { responses -> Void in
                XCTAssertEqual(responses[0], "this is some text two")
                XCTAssertEqual(responses[1], "this is some text")
            }
            .assertResolves()
    }

    func testFailedFetch() {

        let expect = expectation(description: "Fetch call returns")

        FetchOperation.fetch("http://localhost:23423") { error, _ in
            XCTAssert(error != nil)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)
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

        let expectRedirect = expectation(description: "Fetch call returns")

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/redirect-me"))

        FetchOperation.fetch(request) { _, response in
            XCTAssert(response != nil)
            XCTAssertEqual(response!.status, 201)

            XCTAssert(response!.url.absoluteString == TestWeb.serverURL.appendingPathComponent("/test.txt").absoluteString)
            expectRedirect.fulfill()
        }

        wait(for: [expectRedirect], timeout: 10)
    }

    func testRedirectNoFollow() {
        self.setupRedirectURLs()

        let expectNotRedirect = expectation(description: "Fetch call does not redirect")

        let noRedirectRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/redirect-me"))
        noRedirectRequest.redirect = .Manual

        FetchOperation.fetch(noRedirectRequest) { _, response in
            XCTAssert(response != nil, "Response should exist")
            XCTAssert(response!.status == 301, "Should be a 301 status")
            XCTAssert(response!.headers.get("Location") == "/test.txt", "URL should be correct")
            XCTAssert(response!.url.absoluteString == TestWeb.serverURL.appendingPathComponent("/redirect-me").absoluteString)
            expectNotRedirect.fulfill()
        }

        wait(for: [expectNotRedirect], timeout: 10)
    }

    func testRedirectError() {
        self.setupRedirectURLs()

        let expectError = expectation(description: "Fetch call errors on redirect")

        let errorRequest = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/redirect-me"))
        errorRequest.redirect = .Error

        FetchOperation.fetch(errorRequest) { error, _ in
            XCTAssert(error != nil, "Error should exist")
            expectError.fulfill()
        }

        wait(for: [expectError], timeout: 100)
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

        FetchOperation.fetch(postRequest) { error, _ in
            XCTAssert(error == nil, "Should not error")
        }

        wait(for: [expectResponse], timeout: 1)
    }

    func testJSFetch() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
        }

        let expectResponse = expectation(description: "JS Fetch worked")

        let context = JSContext()!
        FetchOperation.addToJSContext(context: context)

        let promise = context.evaluateScript("""
            fetch('\(TestWeb.serverURL.appendingPathComponent("/test.txt").absoluteString)')
            .then(function(res) {
            
            function valOrNo(val) {
                if (typeof val == "undefined") {
                    return -1;
                } else {
                    return val;
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

        XCTAssert(promise != nil)

        JSPromise.resolve(promise!) { err, val in
            XCTAssert(err == nil)

            let obj = val!.toDictionary()!

            for (key, val) in obj {
                NSLog("KEY: \(key), VAL: \(val)")
                let valInt = val as? Int
                XCTAssert(valInt == nil || valInt != -1, "Property \(key) should exist")
            }

            expectResponse.fulfill()
        }

        wait(for: [expectResponse], timeout: 10)
    }
}
