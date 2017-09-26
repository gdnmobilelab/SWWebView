import XCTest
import GCDWebServers
import ServiceWorker
import JavaScriptCore
import PromiseKit
@testable import ServiceWorkerContainer

class ImportScriptsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestWeb.createServer()
        CoreDatabase.resetForTests()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        TestWeb.destroyServer()
        super.tearDown()
    }

    func testImportingAScript() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/import.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: "var test = 100; //testImporting ".data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        let worker = ServiceWorker(id: "TEST", url: TestWeb.serverURL.appendingPathComponent("test.js"), registration: DummyServiceWorkerRegistration(), state: .activated, content: "")

        worker.importScripts = ServiceWorkerHooks.importScripts

        worker.evaluateScript("importScripts('import.js'); test")
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toInt32(), 100)
            }
            .assertResolves()
    }

    func testImportingASecondTimeUsesCache() {

        var toReturn = "test = 100; //testSecondTime"

        TestWeb.server!.addHandler(forMethod: "GET", path: "/import.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(data: toReturn.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        let worker = ServiceWorker(id: "TEST", url: TestWeb.serverURL.appendingPathComponent("test.js"), registration: DummyServiceWorkerRegistration(), state: .activated, content: "")

        worker.importScripts = ServiceWorkerHooks.importScripts

        worker.evaluateScript("importScripts('import.js');")
            .then { _ -> Promise<JSValue?> in
                return worker.evaluateScript("test = 150")
            }
            .then { _ -> Promise<JSValue?> in
                toReturn = "test = 200"
                return worker.evaluateScript("importScripts('import.js'); test")
            }
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toInt32(), 100)
            }
            .assertResolves()
    }

    func testSecondWorkerDoesNotUseCache() {

        var toReturn = "test = 100; //testNotUseCache"

        TestWeb.server!.addHandler(forMethod: "GET", path: "/import.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(data: toReturn.data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        let worker = ServiceWorker(id: "TEST", url: TestWeb.serverURL.appendingPathComponent("test.js"), registration: DummyServiceWorkerRegistration(), state: .activated, content: "var test = 50")

        worker.importScripts = ServiceWorkerHooks.importScripts
        URLCache.shared.removeAllCachedResponses()
        worker.evaluateScript("importScripts('import.js');")
            .then { _ -> Promise<JSValue?> in
                return worker.evaluateScript("test = 150")
            }
            .then { _ -> Promise<JSValue?> in
                URLCache.shared.removeAllCachedResponses()
                toReturn = "test = 200"
                let newWorker = ServiceWorker(id: "TEST-TWO", url: TestWeb.serverURL.appendingPathComponent("test.js"), registration: DummyServiceWorkerRegistration(), state: .activated, content: "var test = 50")

                newWorker.importScripts = ServiceWorkerHooks.importScripts

                return newWorker.evaluateScript("importScripts('import.js'); test")
            }
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toInt32(), 200)
            }
            .assertResolves()
    }
}
