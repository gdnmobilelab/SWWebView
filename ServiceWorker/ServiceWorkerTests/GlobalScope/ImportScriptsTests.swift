import XCTest
@testable import ServiceWorker
import JavaScriptCore
import GCDWebServers
import PromiseKit

class ImportScriptsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestWeb.createServer()
    }

    override func tearDown() {
        super.tearDown()
        TestWeb.destroyServer()
    }

    class TestImportDelegate: NSObject, ServiceWorkerDelegate {

        func serviceWorkerGetDomainStoragePath(_: ServiceWorker) throws -> URL {
            throw ErrorMessage("Not implemented")
        }

        typealias ImportFunction = (URL, @escaping (Error?, String?) -> Void) -> Void

        let importFunc: ImportFunction
        var content: String

        init(_ importFunc: @escaping ImportFunction) {
            self.importFunc = importFunc
            self.content = ""
        }

        func serviceWorker(_: ServiceWorker, importScript: URL, onQueue _: DispatchQueue, _ callback: @escaping (Error?, String?) -> Void) {
            self.importFunc(importScript, callback)
        }

        func serviceWorkerGetScriptContent(_: ServiceWorker) throws -> String {
            return self.content
        }

        func getCoreDatabaseURL() -> URL {
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }
    }

    func testImportingAScript() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let delegate = TestImportDelegate { url, cb in
            XCTAssertEqual(url.absoluteString, "http://www.example.com/test.js")
            cb(nil, "testValue = 'hello';")
        }

        sw.delegate = delegate

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }

    //    func testImportingMultipleScripts() {
    //
    //        let sw = ServiceWorker.createTestWorker(id: name)
    //
    //        let delegate = TestImportDelegate { urls, cb in
    //            XCTAssertEqual(urls[0].absoluteString, "http://www.example.com/test.js")
    //            XCTAssertEqual(urls[1].absoluteString, "http://www.example.com/test2.js")
    //            cb(nil, ["testValue = 'hello';", "testValue = 'hello2';"])
    //        }
    //
    //        sw.delegate = delegate
    //
    //        sw.evaluateScript("importScripts(['test.js', 'test2.js']); testValue;")
    //            .then { returnVal in
    //                XCTAssertEqual(returnVal!.toString(), "hello2")
    //            }
    //            .assertResolves()
    //    }

    func testImportingWithAsyncOperation() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.js", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            GCDWebServerDataResponse(data: "self.testValue = 'hello2';".data(using: String.Encoding.utf8)!, contentType: "text/javascript")
        }

        let delegate = TestImportDelegate { _, cb in
            NSLog("Running fetch")
            FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.js"))
                .then { res -> Promise<String> in
                    NSLog("Got fetch")
                    return res.text()
                }
                .then { text in
                    cb(nil, text)
                }
                .catch { error in
                    cb(error, nil)
                }
        }

        delegate.content = "importScripts('test.js');"

        let sw = ServiceWorker.createTestWorker(id: name)
        ServiceWorker.createTestWorker(id: name)
        sw.delegate = delegate

        sw.evaluateScript("testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello2")
            }
            .assertResolves()
    }
}
