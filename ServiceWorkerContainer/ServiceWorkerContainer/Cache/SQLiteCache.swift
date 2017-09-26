import Foundation
import ServiceWorker
import JavaScriptCore

@objc public class SQLiteCache: NSObject, Cache {

    let storage: SQLiteCacheStorage

    init(in storage: SQLiteCacheStorage) {
        self.storage = storage
    }

    public func match(_: JSValue, _: [String: Any]) -> JSValue {
        return JSContext.current().globalObject
    }

    public func matchAll(_: JSValue, _: [String: Any]) -> JSValue {
        return JSContext.current().globalObject
    }

    public func add(_: JSValue) -> JSValue {
        return JSContext.current().globalObject
    }

    public func addAll(_: JSValue) -> JSValue {
        return JSContext.current().globalObject
    }

    public func put(_: FetchRequest, _: FetchResponse) -> JSValue {
        return JSContext.current().globalObject
    }

    public func delete(_: JSValue, _: [String: Any]) -> JSValue {
        return JSContext.current().globalObject
    }

    public func keys(_: JSValue, _: [String: Any]) -> JSValue {
        return JSContext.current().globalObject
    }
}
