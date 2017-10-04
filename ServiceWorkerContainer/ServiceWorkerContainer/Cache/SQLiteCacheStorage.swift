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

    func getRequest(fromJSValue value: JSValue) throws -> FetchRequest {
        let request: FetchRequest
        if value.isString {

            guard let stringURL = value.toString() else {
                throw ErrorMessage("Could not create native string from value provided")
            }

            guard let worker = self.worker else {
                throw ErrorMessage("Lost reference to ServiceWorker")
            }

            guard let requestURL = URL(string: stringURL, relativeTo: worker.url) else {
                throw ErrorMessage("Could not create Request from URL provided")
            }

            request = FetchRequest(url: requestURL)
        } else if value.isInstance(of: FetchRequest.self) {

            guard let asRequest = value.toObjectOf(FetchRequest.self) as? FetchRequest else {
                throw ErrorMessage("Could not convert to a FetchRequest")
            }

            request = asRequest
        } else {
            throw ErrorMessage("Could not parse value given to match")
        }
        return request
    }

    func createMatchWhere(fromRequest request: FetchRequest, andOptions options: [String: Any]?) throws -> (where: String, values: [Any?]) {

        let (urlNoQuery, query) = try self.separateQueryAndMakeSW(fromURL: request.url)

        var wheres: [String] = ["request_url_no_query = ?"]
        var values: [Any?] = [urlNoQuery]

        let ignoreMethod = options?["ignoreMethod"] as? Bool ?? false
        let ignoreSearch = options?["ignoreSearch"] as? Bool ?? false

        if let cacheName = options?["cacheName"] as? String {
            wheres.append("cache_name = ?")
            values.append(cacheName)
        }

        if ignoreMethod == false {
            wheres.append("method = ?")
            values.append(request.method)
        }

        if ignoreSearch == false {
            if query == nil {
                wheres.append("request_query IS NULL")
            } else {
                wheres.append("request_query = ?")
                values.append(query)
            }
        }

        return (wheres.joined(separator: " AND "), values)
    }

    public func match(_ stringOrRequest: JSValue, _ options: [String: Any]?) -> JSValue? {
        let jsp = JSPromise(context: JSContext.current())

        self.matchAll(stringOrRequest, options, stopAfterFirst: true)
            .then { responses in
                jsp.fulfill(responses.first)
            }
            .catch { error in
                jsp.reject(error)
            }

        return jsp.jsValue
    }

    func matchAll(_ stringOrRequest: JSValue, _ options: [String: Any]?, stopAfterFirst: Bool = false) -> Promise<[FetchResponseProtocol]> {

        do {
            let request = try self.getRequest(fromJSValue: stringOrRequest)

            let (whereString, values) = try self.createMatchWhere(fromRequest: request, andOptions: options)

            let ignoreVary = options?["ignoreVary"] as? Bool ?? false

            let responses = try DBConnectionPool.inConnection(at: self.getDBURL(), type: .cache) { db in
                return try db.select(sql: """
                    SELECT
                        rowid,
                        vary_by_headers,
                        response_headers,
                        response_url,
                        response_status,
                        response_status_text,
                        response_type,
                        response_redirected
                    FROM cache_entries
                    WHERE \(whereString)
                """, values: values) { rs -> [FetchResponseProtocol] in

                    var responses: [FetchResponseProtocol] = []

                    while try rs.next() {

                        if let varyHeadersJSON = try rs.string("vary_by_headers"), ignoreVary == false {

                            let varyHeaders = try FetchHeaders.fromJSON(varyHeadersJSON)
                            let hasFailedMatch = varyHeaders.keys().first(where: { varyHeaders.get($0) != request.headers.get($0) })

                            if hasFailedMatch != nil {
                                continue
                            }
                        }

                        responses.append(try self.makeResponse(fromResultSet: rs, in: db))
                        if stopAfterFirst {
                            // match() only ever needs one response, so we can shortcut the loop
                            return responses
                        }
                    }

                    return responses
                }
            }

            return Promise(value: responses)
        } catch {
            return Promise(error: error)
        }
    }

    fileprivate func makeResponse(fromResultSet rs: SQLiteResultSet, in db: SQLiteConnection) throws -> FetchResponseProtocol {
        guard let responseHeadersJSON = try rs.string("response_headers"), let responseStatus = try rs.int("response_status"),
            let responseStatusText = try rs.string("response_status_text"), let responseRedirected = try rs.int("response_redirected"),
            let responseTypeString = try rs.string("response_type") else {
            throw ErrorMessage("Could not fetch required fields from cache_entries table")
        }

        guard let responseType = ResponseType(rawValue: responseTypeString) else {
            throw ErrorMessage("Did not understand response type stored in database")
        }

        let url = try rs.url("response_url")

        guard let rowID = try rs.int64("rowid") else {
            throw ErrorMessage("Could not fetch row ID for this cache entry")
        }

        let readStream = try db.openBlobReadStream(table: "cache_entries", column: "response_body", row: rowID)

        guard let dispatchQueue = self.worker?.dispatchQueue else {
            throw ErrorMessage("Could not get worker dispatch queue")
        }

        let streamPipe = StreamPipe(from: readStream, bufferSize: 1024, dispatchQueue: dispatchQueue)
        let responseHeaders = try FetchHeaders.fromJSON(responseHeadersJSON)
        let response = FetchResponse(url: url, headers: responseHeaders, status: responseStatus, statusText: responseStatusText, redirected: responseRedirected == 1, streamPipe: streamPipe)

        var corsHeaders: [String]?

        if responseType == .CORS {
            corsHeaders = try rs.string("response_cors_allowed_headers")?.components(separatedBy: ",")
        }

        return try response.getWrappedVersion(for: responseType, corsAllowedHeaders: corsHeaders)
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
                    try db.update(sql: "DELETE FROM cache_entries WHERE cache_name = ?", values: [name])
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

    func getDBURL() throws -> URL {

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

    fileprivate func separateQueryAndMakeSW(fromURL url: URL) throws -> (noQuery: URL, query: String?) {
        guard var requestURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw ErrorMessage("Cannot parse request URL into components")
        }

        requestURLComponents.scheme = "sw"

        let search = requestURLComponents.query

        requestURLComponents.query = nil

        guard let requestURLNoQuery = requestURLComponents.url else {
            throw ErrorMessage("Cannot remove query from URL")
        }

        return (requestURLNoQuery, search)
    }

    func delete(cacheName _: String, request: FetchRequest, options: [String: Any]?) throws {

        let (fields, values) = try self.createMatchWhere(fromRequest: request, andOptions: options)

        try DBConnectionPool.inConnection(at: try self.getDBURL(), type: .cache) { db in
            try db.update(sql: "DELETE FROM cache_entries WHERE \(fields)", values: values)
        }
    }

    //    func keys(cacheName:String, matchRequest) -> [String] {
    //
    //        return try DBConnectionPool.inConnection(at: try self.getDBURL(), type: .cache) { db in
    //            return try db.select(sql: """
    //                SELECT DISTINCT
    //                method, request_url_no_query, request_query, request_headers
    //                WHERE cache_name = ?
    //            """, values: [cacheName]) { rs in
    //            }
    //        }
    //
    //    }

    func put(cacheName: String, request: FetchRequest, response: CacheableFetchResponse) -> Promise<Void> {

        if request.method == "POST" {
            return Promise(error: ErrorMessage("Caching of POST requests is not supported"))
        }

        // SQLite requires us to specify the size of a blob when we insert a row, and
        // not all responses have a Content-Length header, so we download to disk first,
        // then transfer that file into SQLite.
        return response.internalResponse.fileDownload { fileURL, fileSize -> Promise<Void> in
            let (urlNoQuery, query) = try self.separateQueryAndMakeSW(fromURL: request.url)

            let varyHeaders = self.getVaryHeaders(varyHeader: response.headers.get("Vary"), requestHeaders: request.headers)

            var params: [String: Any?] = [
                "cache_name": cacheName,
                "method": request.method,
                "request_url_no_query": urlNoQuery,
                "request_query": query,
                "vary_by_headers": try varyHeaders?.toJSON(),
                "request_headers": try request.headers.toJSON(),
                "response_headers": try response.internalResponse.headers.toJSON(),
                "response_url": response.internalResponse.url?.absoluteString,
                "response_status": response.status,
                "response_status_text": response.statusText,
                "response_redirected": response.redirected ? 1 : 0,
                "response_type": response.responseTypeString,
                "response_body": fileSize
            ]

            if ResponseType(rawValue: response.responseTypeString) == .CORS {
                // This is kind of gross, but we need to store the allowed headers in a CORS response
                // somewhere.
                params["response_cors_allowed_headers"] = response.headers.keys().joined(separator: ",")
            }

            let valuePlaceholders = params.keys.map { $0 == "response_body" ? "zeroblob(?)" : "?" }

            return try DBConnectionPool.inConnection(at: self.getDBURL(), type: .cache) { db in

                // put() overwrites any existing entry. But because this is a SQL database with uniques, etc., we need
                // to actually delete first.

                let (deleteFields, deleteValues) = try self.createMatchWhere(fromRequest: request, andOptions: [:])
                try db.update(sql: "DELETE FROM cache_entries WHERE \(deleteFields)", values: deleteValues)
                if let changes = db.lastNumberChanges {
                    if changes > 0 {
                        Log.info?("Removed an existing entry before adding this new cache item")
                    }
                }

                let columns = params.keys.joined(separator: ",")
                let values = valuePlaceholders.joined(separator: ",")
                let rowID = try db.insert(sql: "INSERT INTO cache_entries(\(columns)) VALUES (\(values))", values: [Any?](params.values))

                let writeStream = try db.openBlobWriteStream(table: "cache_entries", column: "response_body", row: rowID)
                guard let fileStream = InputStream(url: fileURL) else {
                    throw ErrorMessage("Could not open stream to local file")
                }
                guard let dispatchQueue = self.worker?.dispatchQueue else {
                    throw ErrorMessage("Could not get worker dispatch queue")
                }
                return StreamPipe.pipe(from: fileStream, to: writeStream, bufferSize: 1024, dispatchQueue: dispatchQueue)
            }
        }
    }
}
