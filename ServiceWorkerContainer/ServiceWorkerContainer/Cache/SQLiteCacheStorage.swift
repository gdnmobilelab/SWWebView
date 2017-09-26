import Foundation
import ServiceWorker
import JavaScriptCore

@objc public class SQLiteCacheStorage: NSObject, CacheStorage {

    public static var CacheClass = SQLiteCache.self as Cache.Type

    let origin: URL

    public init(for url: URL) throws {

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw ErrorMessage("Could not parse input URL")
        }
        components.path = "/"

        guard let origin = components.url else {
            throw ErrorMessage("Could not create origin URL")
        }
        self.origin = origin
        super.init()
    }

    public func match(_: JSValue, _: [String: Any]) -> JSValue {
        return JSContext.current().globalObject
    }

    public func has(_: String) -> JSValue {
        return JSContext.current().globalObject
    }

    public func open(_: String) -> JSValue {
        return JSContext.current().globalObject
    }

    public func delete(_: String) -> JSValue {
        return JSContext.current().globalObject
    }

    public func keys() -> JSValue {
        return JSContext.current().globalObject
    }

    /// We don't want to keep these SQL connections open longer than we have to for memory reasons
    /// but we also don't want to duplicate a connection if it's already open. When a connection is
    /// deinit-ed it automatically closes, so we can just rely on the weak references here to close
    /// when we're done.
    fileprivate static var currentOpenConnections = NSHashTable<SQLiteConnection>.weakObjects()

    fileprivate static func getConnection(for url: URL) throws -> SQLiteConnection {

        let existing = currentOpenConnections.allObjects.first(where: { $0.url.absoluteString == url.absoluteString })

        if let doesExist = existing {
            return doesExist
        }

        let newConnection = try SQLiteConnection(url)
        self.currentOpenConnections.add(newConnection)
        return newConnection
    }

    //    fileprivate static func getURL(for _: String) -> URL {
    //    }

    func put(cacheName _: String, request _: FetchRequest, response _: FetchResponse) {

        //        let connection = SQLiteCacheStorage.getConnection(for: <#T##URL#>)
    }
}
