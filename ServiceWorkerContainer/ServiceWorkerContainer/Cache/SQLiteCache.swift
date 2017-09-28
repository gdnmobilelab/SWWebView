import Foundation
import ServiceWorker
import JavaScriptCore

@objc public class SQLiteCache: NSObject, Cache {

    let storage: SQLiteCacheStorage
    let name: String

    init(in storage: SQLiteCacheStorage, name: String) {
        self.storage = storage
        self.name = name
    }

    public func match(_ toMatch: JSValue, _ options: [String: Any]) -> JSValue? {

        var modified = options
        modified["cacheName"] = self.name

        return self.storage.match(toMatch, modified)
    }

    public func matchAll(_: JSValue, _: [String: Any]) -> JSValue? {
        return JSContext.current().globalObject
    }

    public func add(_: JSValue) -> JSValue? {
        return JSContext.current().globalObject
    }

    public func addAll(_: JSValue) -> JSValue? {
        return JSContext.current().globalObject
    }

    public func put(_ request: FetchRequest, _ response: CacheableFetchResponse) -> JSValue? {
        return self.storage.put(cacheName: self.name, request: request, response: response)
            .toJSPromise(in: JSContext.current())
    }

    public func delete(_: JSValue, _: [String: Any]) -> JSValue? {
        return JSContext.current().globalObject
    }

    public func keys(_: JSValue, _: [String: Any]) -> JSValue? {
        return JSContext.current().globalObject
    }
}
