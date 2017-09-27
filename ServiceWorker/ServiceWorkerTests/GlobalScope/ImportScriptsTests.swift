import XCTest
@testable import ServiceWorker
import JavaScriptCore

class ImportScriptsTests: XCTestCase {

    class TestImportDelegate: ServiceWorkerDelegate {

        func serviceWorkerGetDomainStoragePath(_: ServiceWorker) throws -> URL {
            throw ErrorMessage("Not implemented")
        }

        typealias ImportFunction = ([URL], @escaping (Error?, [String]?) -> Void) -> Void

        let importFunc: ImportFunction

        init(_ importFunc: @escaping ImportFunction) {
            self.importFunc = importFunc
        }

        func serviceWorker(_: ServiceWorker, importScripts: [URL], _ callback: @escaping (Error?, [String]?) -> Void) {
            self.importFunc(importScripts, callback)
        }

        func serviceWorkerGetScriptContent(_: ServiceWorker) throws -> String {
            return ""
        }

        func getCoreDatabaseURL() -> URL {
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }
    }

    func testImportingAScript() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let delegate = TestImportDelegate { urls, cb in
            XCTAssertEqual(urls[0].absoluteString, "http://www.example.com/test.js")
            cb(nil, ["testValue = 'hello';"])
        }

        sw.delegate = delegate

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal -> Void in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }

    func testImportingMultipleScripts() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let delegate = TestImportDelegate { urls, cb in
            XCTAssertEqual(urls[0].absoluteString, "http://www.example.com/test.js")
            XCTAssertEqual(urls[1].absoluteString, "http://www.example.com/test2.js")
            cb(nil, ["testValue = 'hello';", "testValue = 'hello2';"])
        }

        sw.delegate = delegate

        sw.evaluateScript("importScripts(['test.js', 'test2.js']); testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello2")
            }
            .assertResolves()
    }

    func testImportingWithAsyncOperation() {

        let sw = ServiceWorker.createTestWorker(id: name)

        let delegate = TestImportDelegate { _, cb in

            DispatchQueue.global().async {
                cb(nil, ["testValue = 'hello';"])
            }
        }

        sw.delegate = delegate

        sw.evaluateScript("importScripts('test.js'); testValue;")
            .then { returnVal in
                XCTAssertEqual(returnVal!.toString(), "hello")
            }
            .assertResolves()
    }
}
