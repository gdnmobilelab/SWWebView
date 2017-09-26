import Foundation
import JavaScriptCore

@objc public protocol CacheStorageJSExports: JSExport {
    func match(_ request: JSValue, _ options: [String: Any]) -> JSValue
    func has(_ cacheName: String) -> JSValue
    func open(_ cacheName: String) -> JSValue
    func delete(_ cacheName: String) -> JSValue
    func keys() -> JSValue
}

@objc public protocol CacheStorage: CacheStorageJSExports, JSExport {
    static var CacheClass: Cache.Type { get }
}
