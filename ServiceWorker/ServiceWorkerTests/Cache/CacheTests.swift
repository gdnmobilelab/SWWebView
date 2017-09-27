import XCTest
@testable import ServiceWorker
import PromiseKit
import JavaScriptCore

class CacheTests: XCTestCase {

    static func stubReject() -> JSValue {
        let p = JSPromise(context: JSContext.current())
        p.reject(ErrorMessage("Not using this"))
        return p.jsValue!
    }

    @objc class TestCache: NSObject, Cache {

        let name: String
        init(name: String) {
            self.name = name
            super.init()
        }

        func match(_: JSValue, _: [String: Any]) -> JSValue? {
            return stubReject()
        }

        func matchAll(_: JSValue, _: [String: Any]) -> JSValue? {
            return stubReject()
        }

        func add(_: JSValue) -> JSValue? {
            return stubReject()
        }

        func addAll(_: JSValue) -> JSValue? {
            return stubReject()
        }

        func put(_: FetchRequest, _: FetchResponse) -> JSValue? {
            return stubReject()
        }

        func delete(_: JSValue, _: [String: Any]) -> JSValue? {
            return stubReject()
        }

        func keys(_: JSValue, _: [String: Any]) -> JSValue? {
            let promise = JSPromise(context: JSContext.current())
            let testKeys = ["\(self.name)-file1.js", "\(self.name)-file2.css"]
            promise.fulfill(testKeys)
            return promise.jsValue!
        }
    }

    @objc class TestStorage: NSObject, CacheStorage {

        static var CacheClass: Cache.Type = TestCache.self

        let names: [String]
        init(names: [String]) {
            self.names = names
        }

        func match(_: JSValue, _: [String: Any]) -> JSValue? {
            return stubReject()
        }

        func has(_: String) -> JSValue? {
            return stubReject()
        }

        func open(_ cacheName: String) -> JSValue? {
            let promise = JSPromise(context: JSContext.current())
            promise.fulfill(TestCache(name: cacheName))
            return promise.jsValue!
        }

        func delete(_: String) -> JSValue? {
            return stubReject()
        }

        func keys() -> JSValue? {

            let promise = JSPromise(context: JSContext.current())
            promise.fulfill(self.names)
            return promise.jsValue!
        }
    }

    func testShouldFailByDefault() {

        let sw = ServiceWorker.createTestWorker(id: self.name)

        sw.evaluateScript("""
            self.caches.keys()
        """)
            .recover { error -> JSValue? in
                XCTAssertEqual("\(error)", "Error: CacheStorage has not been provided for this worker")
                return nil
            }
            .assertResolves()
    }

    func testShouldUseImplementationWhenProvided() {

        let sw = ServiceWorker.createTestWorker(id: self.name)
        sw.cacheStorage = TestStorage(names: ["TestCache", "TestCache2"])

        sw.evaluateScript("""
            self.caches.keys()
        """)
            .then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }
            .then { items -> Void in
                let arr = items!.value.toArray() as! [String]
                XCTAssertEqual(arr[0], "TestCache")
                XCTAssertEqual(arr[1], "TestCache2")
            }
            .assertResolves()
    }

    func testShouldOpenCacheAndGiveKeys() {

        let sw = ServiceWorker.createTestWorker(id: self.name)
        sw.cacheStorage = TestStorage(names: ["TestCache"])

        sw.evaluateScript("""
            self.caches.open("TestCache")
            .then((cache) => cache.keys())
        """)
            .then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }
            .then { items -> Void in
                let arr = items!.value.toArray() as! [String]
                XCTAssertEqual(arr[0], "TestCache-file1.js")
                XCTAssertEqual(arr[1], "TestCache-file2.css")
            }
            .assertResolves()
    }

    func testShouldHaveClassesOnGlobalObject() {
        let sw = ServiceWorker.createTestWorker(id: self.name)
        sw.cacheStorage = TestStorage(names: ["TestCache"])

        sw.evaluateScript("[Cache,CacheStorage]")
            .then { jsVal -> Void in
                let arr = jsVal!.toArray()!
                XCTAssert(arr[0] as! Cache.Type === TestCache.self as Cache.Type)
                XCTAssert(arr[1] as! CacheStorage.Type === TestStorage.self as CacheStorage.Type)
            }
            .assertResolves()
    }
}
