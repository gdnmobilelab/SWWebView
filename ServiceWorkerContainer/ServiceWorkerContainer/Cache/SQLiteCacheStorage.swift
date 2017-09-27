import Foundation
import ServiceWorker
import JavaScriptCore
import PromiseKit

@objc public class SQLiteCacheStorage: NSObject, CacheStorage {

    public static var CacheClass = SQLiteCache.self as Cache.Type

    //    let origin: URL

    weak var worker: ServiceWorker?

    public init(for worker: ServiceWorker) throws {

        self.worker = worker

        super.init()
    }

    public func match(_: JSValue, _: [String: Any]) -> JSValue? {
        return JSContext.current().globalObject
    }

    fileprivate func nativeHas(_ name: String) throws -> Bool {
        return try DBConnectionPool.inConnection(at: self.getDBURL(), type: .cache) { db in
            try db.select(sql: "SELECT COUNT(*) as count FROM caches WHERE cache_name = ?", values: [name]) { rs in
                if try rs.next() == false {
                    throw ErrorMessage("No rows were returned when checking for count")
                }
                guard let rowCount = try rs.int("count") else {
                    throw ErrorMessage("Could not get count")
                }
                return rowCount > 0
            }
        }
    }

    public func has(_ name: String) -> JSValue? {
        return firstly {
            Promise(value: try self.nativeHas(name))
        }.toJSPromise(in: JSContext.current())
    }

    public func open(_ name: String) -> JSValue? {

        return firstly { () -> Promise<SQLiteCache> in

            try DBConnectionPool.inConnection(at: self.getDBURL(), type: .cache) { db in
                try db.update(sql: "INSERT OR IGNORE INTO caches(cache_name) VALUES (?)", values: [name])
            }

            return Promise(value: SQLiteCache(in: self, name: name))

        }.toJSPromise(in: JSContext.current())
    }

    public func delete(_ name: String) -> JSValue? {

        return firstly { () -> Promise<Bool> in

            let alreadyExists = try self.nativeHas(name)
            if alreadyExists {
                try DBConnectionPool.inConnection(at: self.getDBURL(), type: .cache) { db in
                    try db.update(sql: "DELETE FROM caches WHERE cache_name = ?", values: [name])
                }
            }

            return Promise(value: alreadyExists)

        }.toJSPromise(in: JSContext.current())
    }

    public func keys() -> JSValue? {

        return firstly {
            try DBConnectionPool.inConnection(at: self.getDBURL(), type: DatabaseType.cache) { db in
                return try db.select(sql: "SELECT cache_name FROM caches") { rs -> Promise<[String]> in

                    var names: [String] = []
                    while try rs.next() {
                        guard let name = try rs.string("cache_name") else {
                            throw ErrorMessage("Entry in the caches table has no name")
                        }
                        names.append(name)
                    }

                    return Promise(value: names)
                }
            }
        }.toJSPromise(in: JSContext.current())
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

    fileprivate func getDBURL() throws -> URL {

        guard let worker = self.worker else {
            throw ErrorMessage("SQLiteCacheStorage no longer has a reference to the worker")
        }

        guard let delegate = worker.delegate else {
            throw ErrorMessage("No delegate set to get storage path")
        }

        let baseStorageURL = try delegate.serviceWorkerGetDomainStoragePath(worker)

        return baseStorageURL.appendingPathComponent("caches.db")
    }

    fileprivate func getVaryHeaders(varyHeader: String?, requestHeaders: FetchHeaders) -> FetchHeaders? {

        guard let varyString = varyHeader else {
            return nil
        }

        // The Vary header complicates things a lot, but basically we want to store
        // a separate header collection with the request headers used that our cache
        // varies by.

        let specifiedVaryHeaders = FetchHeaders()

        varyString.split(separator: ",")
            .sorted(by: { a, b in
                // We want our key ordering to be consistent no matter
                // what order they are sent by the server
                a < b
            })
            .forEach { splitItem in

                let trimmedSplitItem = splitItem.trimmingCharacters(in: CharacterSet.whitespaces)

                // The request might not necessarily provide this header. But if it does,
                // add to our collection.

                if let requestHasHeader = requestHeaders.get(trimmedSplitItem) {
                    specifiedVaryHeaders.append(trimmedSplitItem, requestHasHeader)
                }
            }

        return specifiedVaryHeaders
    }

    func put(cacheName: String, request: FetchRequest, response: FetchResponse) -> Promise<Void> {

        if request.method == "POST" {
            return Promise(error: ErrorMessage("Caching of POST requests is not supported"))
        }

        // SQLite requires us to specify the size of a blob when we insert a row, and
        // not all responses have a Content-Length header, so we download to disk first,
        // then transfer that file into SQLite.

        return response.fileDownload { fileURL, fileSize -> Promise<Data> in
            guard var requestURLComponents = URLComponents(url: request.url, resolvingAgainstBaseURL: true) else {
                throw ErrorMessage("Cannot parse request URL into components")
            }

            let search = requestURLComponents.query

            requestURLComponents.query = nil

            guard let requestURLNoQuery = requestURLComponents.url else {
                throw ErrorMessage("Cannot remove query from URL")
            }

            let varyHeaders = self.getVaryHeaders(varyHeader: response.headers.get("Vary"), requestHeaders: request.headers)

            let params: [Any?] = [
                cacheName,
                request.method,
                requestURLNoQuery,
                search,
                try varyHeaders?.toJSON(),
                try request.headers.toJSON(),
                try response.headers.toJSON(),
                response.url,
                response.status,
                fileSize
            ]

            return try DBConnectionPool.inConnection(at: self.getDBURL(), type: .cache) { db in

                let rowID = try db.insert(sql: """
                    INSERT INTO cache_entries(
                        cache_name,
                        method,
                        request_url_no_query,
                        request_query,
                        vary_by_headers,
                        request_headers,
                        response_headers,
                        response_url,
                        response_status,
                        response_body)
                    VALUES
                        (?,?,?,?,?,?,?,?,?,zeroblob(?))
                """, values: params)

                let writeStream = try db.openBlobWriteStream(table: "cache_entries", column: "response_body", row: rowID)

                return try writeStream.pipeReadableStream(stream: ReadableStream.fromLocalURL(fileURL, bufferSize: 32768)) // chunks of 32KB. No idea what is best.
            }
        }
        .then { _ in
            ()
        }
    }
}
