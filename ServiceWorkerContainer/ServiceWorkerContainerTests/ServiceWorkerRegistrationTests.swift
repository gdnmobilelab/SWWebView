//
//  ServiceWorkerRegistrationTests.swift
//  ServiceWorkerContainerTests
//
//  Created by alastair.coote on 14/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import GCDWebServers
import JavaScriptCore
import PromiseKit
@testable import ServiceWorkerContainer

class ServiceWorkerRegistrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoreDatabase.clearForTests()
        TestWeb.createServer()
        URLCache.shared.removeAllCachedResponses()
    }

    override func tearDown() {
        TestWeb.destroyServer()
    }

    func testCreateBlankRegistration() {

        var reg: ServiceWorkerRegistration?

        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com")!))
        XCTAssertEqual(reg!.scope.absoluteString, "https://www.example.com")

        // An attempt to create a registration when one already exists should fail
        XCTAssertThrowsError(try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com")!))
    }

    func testFailRegistrationOutOfScope() {

        var reg: ServiceWorkerRegistration?

        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com/one")!))
        XCTAssertEqual(reg!.scope.absoluteString, "https://www.example.com/one")

        reg!.register(URL(string: "https://www.example.com/two/test.js")!)
            .assertRejects() }

    func testShouldPopulateWorkerFields() {

        XCTAssertNoThrow(try CoreDatabase.inConnection { connection in

            try ["active", "installing", "waiting", "redundant"].forEach { state in

                let dummyWorkerValues: [Any] = [
                    "TEST_ID_" + state,
                    "https://www.example.com/worker.js",
                    "DUMMY_HEADERS",
                    "DUMMY_CONTENT",
                    ServiceWorkerInstallState.activated.rawValue,
                    "https://www.example.com",
                ]

                _ = try connection.insert(sql: "INSERT INTO workers (worker_id, url, headers, content, install_state, scope) VALUES (?,?,?,?,?,?)", values: dummyWorkerValues)
            }

            let registrationValues = ["https://www.example.com", "TEST_ID", "TEST_ID_active", "TEST_ID_installing", "TEST_ID_waiting", "TEST_ID_redundant"]
            _ = try connection.insert(sql: "INSERT INTO registrations (scope, id, active, installing, waiting, redundant) VALUES (?,?,?,?,?,?)", values: registrationValues)
        })

        var reg: ServiceWorkerRegistration?
        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.get(scope: URL(string: "https://www.example.com")!)!)

        XCTAssert(reg!.active!.id == "TEST_ID_active")
        XCTAssert(reg!.installing!.id == "TEST_ID_installing")
        XCTAssert(reg!.waiting!.id == "TEST_ID_waiting")
        XCTAssert(reg!.redundant!.id == "TEST_ID_redundant")
    }

    func testShouldInstallWorker() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: """
            
            var installed = false;
            self.addEventListener("install", function() {
                installed = true
            });
            "testtest!"
            
            """.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        firstly { () -> Promise<Void> in
            let reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL)
            return reg.register(TestWeb.serverURL.appendingPathComponent("test.js"))
                .then { () -> Promise<JSValue?> in
                    XCTAssertNotNil(reg.active)
                    return reg.active!.evaluateScript("installed")
                }
                .then { jsVal -> Void in
                    XCTAssertEqual(jsVal!.toBool(), true)
                }
        }
        .assertResolves()
    }

    func testShouldStayWaitingWhenActiveWorkerExists() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(text: "console.log('load')")
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test2.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(text: "console.log('load2')")
        }

        firstly { () -> Promise<Void> in
            let reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL)
            return reg.register(TestWeb.serverURL.appendingPathComponent("test.js"))
                .then { () -> Promise<Void> in
                    let currentActive = reg.active
                    XCTAssertNotNil(currentActive)
                    return reg.register(TestWeb.serverURL.appendingPathComponent("test2.js"))
                        .then { () -> Void in
                            XCTAssertEqual(currentActive, reg.active)
                            XCTAssertNotNil(reg.waiting)
                            XCTAssertEqual(reg.active!.url.absoluteString, TestWeb.serverURL.appendingPathComponent("test.js").absoluteString)
                            XCTAssertEqual(reg.waiting!.url.absoluteString, TestWeb.serverURL.appendingPathComponent("test2.js").absoluteString)
                        }
                }
        }
        .assertResolves()
    }

    func testShouldReplaceWhenSkipWaitingCalled() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: "console.log('loader!')".data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test2.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: """
                self.addEventListener('install', function() {
                    self.skipWaiting();
                })
            """.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        firstly { () -> Promise<Void> in
            let reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL)
            return reg.register(TestWeb.serverURL.appendingPathComponent("test.js"))
                .then { () -> Promise<Void> in
                    let currentActive = reg.active
                    XCTAssertNotNil(currentActive)
                    return reg.register(TestWeb.serverURL.appendingPathComponent("test2.js"))
                        .then { () -> Void in
                            XCTAssertEqual(currentActive, reg.redundant)
                            XCTAssertNotNil(reg.active)
                            XCTAssertEqual(reg.active?.url.absoluteString, TestWeb.serverURL.appendingPathComponent("test2.js").absoluteString)
                            XCTAssertEqual(reg.redundant?.url.absoluteString, TestWeb.serverURL.appendingPathComponent("test.js").absoluteString)
                        }
                }
        }
        .assertResolves()
    }

    func testShouldBecomeRedundantIfInstallFails() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: """
                self.addEventListener('install', function(e) {
                    e.waitUntil(new Promise(function(fulfill, reject) {
                        reject(new Error("no"))
                    }))
                })
            """.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        var reg: ServiceWorkerRegistration?

        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL))

        let expect = expectation(description: "Registration fails")

        reg!.register(TestWeb.serverURL.appendingPathComponent("test.js"))
            .then { () -> Void in
                XCTFail("Should not succeed")
            }
            .catch { error in
                XCTAssertNotNil(reg!.redundant)
                XCTAssertEqual("\(error)", "no")
                expect.fulfill()
            }

        wait(for: [expect], timeout: 1)
    }

    func testActiveShouldRemainWhenInstallingWorkerFails() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: "".data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test2.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: """
                self.addEventListener('install', function() {
                    self.skipWaiting();
                })
                self.addEventListener('activate', function(e) {
                    e.waitUntil(new Promise(function(fulfill,reject) {
                        reject(new Error("no"));
                    }))
                });
            """.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        var reg: ServiceWorkerRegistration?

        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL))

        let expect = expectation(description: "Registration completes")

        reg!.register(TestWeb.serverURL.appendingPathComponent("test.js"))
            .then { () -> Promise<Void> in
                let currentActive = reg!.active
                XCTAssertNotNil(currentActive)
                return reg!.register(TestWeb.serverURL.appendingPathComponent("test2.js"))
                    .then {
                        XCTFail("Should not succeed!")
                    }
                    .recover { _ -> Void in
                        XCTAssertEqual(currentActive, reg!.active)
                        XCTAssertNotNil(reg!.redundant)
                        XCTAssertEqual(reg!.active?.url.absoluteString, TestWeb.serverURL.appendingPathComponent("test.js").absoluteString)
                        XCTAssertEqual(reg!.redundant?.url.absoluteString, TestWeb.serverURL.appendingPathComponent("test2.js").absoluteString)
                        expect.fulfill()
                    }
            }
            .catch { error in
                XCTFail("\(error)")
            }

        wait(for: [expect], timeout: 1)
    }

    func testShouldFailWhenJSDoesNotParse() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: "][".data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        var reg: ServiceWorkerRegistration?

        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL))

        let expect = expectation(description: "Registration completes")

        reg!.register(TestWeb.serverURL.appendingPathComponent("test.js"))
            .then { () -> Void in
                XCTFail("Should not succeed")
            }
            .catch { _ in
                XCTAssertNotNil(reg!.redundant)
                expect.fulfill()
            }

        wait(for: [expect], timeout: 1)
    }

    func testShouldNotUpdateWhenBytesMatch() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: """
            
            var installed = false;
            self.addEventListener("install", function() {
                installed = true
            });
            
            """.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        var reg: ServiceWorkerRegistration?

        XCTAssertNoThrow(reg = try ServiceWorkerRegistration.create(scope: TestWeb.serverURL))

        let expect = expectation(description: "Registration completes")

        reg!.register(TestWeb.serverURL.appendingPathComponent("test.js"))
            .then {
                XCTAssertNotNil(reg!.active)
                return reg!.update()
            }
            .then { () -> Void in
                XCTAssertNil(reg!.waiting)
                return try CoreDatabase.inConnection { db -> Void in
                    try db.select(sql: "SELECT count(*) as workercount FROM workers") { resultSet in
                        _ = resultSet.next()
                        XCTAssertEqual(try resultSet.int("workercount"), 1)
                        expect.fulfill()
                    }
                }
            }
            .catch { error in
                XCTFail("\(error)")
            }

        wait(for: [expect], timeout: 1)
    }

    func testShouldUnregister() {
        self.testShouldInstallWorker()
        firstly { () -> Promise<Void> in
            let reg = try ServiceWorkerRegistration.get(scope: TestWeb.serverURL)!
            let worker = reg.active!
            return reg.unregister()
                .then { () -> Void in
                    XCTAssertEqual(reg.unregistered, true)
                    XCTAssertEqual(worker.state, ServiceWorkerInstallState.redundant)
                }
        }
        .assertResolves()
    }
}
