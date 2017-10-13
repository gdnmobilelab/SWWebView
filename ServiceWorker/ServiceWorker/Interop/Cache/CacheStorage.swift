import Foundation
import JavaScriptCore

/// Should resolve to JS promises. Like Cache, should probably actually be all native,
/// and be wrapped internally. Otherwise we might end up leaking JSValues everywhere.
@objc public protocol CacheStorageJSExports: JSExport {
    func match(_ request: JSValue, _ options: [String: Any]?) -> JSValue?
    func has(_ cacheName: String) -> JSValue?
    func open(_ cacheName: String) -> JSValue?
    func delete(_ cacheName: String) -> JSValue?
    func keys() -> JSValue?
}

@objc public protocol CacheStorage: CacheStorageJSExports, JSExport {

    /// This is used to define the Cache object in a worker's global scope - probaby
    /// not strictly necessary, but it matches what browsers do.
    static var CacheClass: Cache.Type { get }
}
