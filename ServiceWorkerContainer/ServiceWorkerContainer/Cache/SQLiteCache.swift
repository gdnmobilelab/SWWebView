import Foundation
import ServiceWorker
import JavaScriptCore
import PromiseKit

@objc public class SQLiteCache: NSObject, Cache {

    let storage: SQLiteCacheStorage
    let name: String

    init(in storage: SQLiteCacheStorage, name: String) {
        self.storage = storage
        self.name = name
    }

    public func match(_ toMatch: JSValue, _ options: [String: Any]?) -> JSValue? {

        var modified = options ?? [:]
        modified["cacheName"] = self.name

        return self.storage.match(toMatch, modified)
    }

    public func matchAll(_ toMatch: JSValue, _ options: [String: Any]?) -> JSValue? {
        var modified = options ?? [:]
        modified["cacheName"] = self.name

        return self.storage.matchAll(toMatch, modified).toJSPromiseInCurrentContext()
    }

    public func add(_ request: JSValue) -> JSValue? {
        return firstly { () -> Promise<Void> in
            let request = try self.storage.getRequest(fromJSValue: request)

            guard let worker = self.storage.worker else {
                throw ErrorMessage("CacheStorage is no longer attached to worker")
            }

            return FetchSession.default.fetch(request, fromOrigin: worker.url)
                .then { response -> Promise<Void> in

                    guard let asCacheable = response as? CacheableFetchResponse else {
                        throw ErrorMessage("Could not convert?")
                    }

                    return self.storage.put(cacheName: self.name, request: request, response: asCacheable)
                }
        }.toJSPromiseInCurrentContext()
    }

    public func addAll(_ requests: JSValue) -> JSValue? {

        return firstly { () -> Promise<Void> in
            guard let array = requests.toArray() else {
                throw ErrorMessage("Arguments must be an array")
            }

            guard let worker = self.storage.worker else {
                throw ErrorMessage("CacheStorage became detatched from worker")
            }

            let mapped = try array.map { item -> FetchRequest in
                if let request = item as? FetchRequest {
                    return request
                }
                if let str = item as? String {
                    guard let url = URL(string: str, relativeTo: worker.url) else {
                        throw ErrorMessage("Could not parse URL given")
                    }

                    return FetchRequest(url: url)
                }

                throw ErrorMessage("Could not parse argument")
            }

            let actualPuts = mapped.map { request in
                return FetchSession.default.fetch(request, fromOrigin: worker.url)
                    .then { response -> Promise<Void> in

                        guard let asCacheable = response as? CacheableFetchResponse else {
                            throw ErrorMessage("Could not convert?")
                        }

                        return self.storage.put(cacheName: self.name, request: request, response: asCacheable)
                    }
            }

            return when(fulfilled: actualPuts)

        }.toJSPromiseInCurrentContext()
    }

    public func put(_ request: FetchRequest, _ response: CacheableFetchResponse) -> JSValue? {
        return self.storage.put(cacheName: self.name, request: request, response: response)
            .toJSPromiseInCurrentContext()
    }

    public func delete(_ request: JSValue, _ options: [String: Any]?) -> JSValue? {

        return firstly { () -> Promise<Bool> in
            var opts = options ?? [:]
            opts["cacheName"] = self.name

            let request = try self.storage.getRequest(fromJSValue: request)
            let (whereString, values) = try self.storage.createMatchWhere(fromRequest: request, andOptions: opts)

            let rowsChanged = try DBConnectionPool.inConnection(at: try self.storage.getDBURL(), type: .cache) { db -> Bool in
                try db.update(sql: "DELETE FROM cache_entries WHERE \(whereString)", values: values)
                return (db.lastNumberChanges ?? 0) > 0
            }

            return Promise(value: rowsChanged)
        }.toJSPromiseInCurrentContext()
    }

    public func keys(_ request: JSValue, _ options: [String: Any]?) -> JSValue? {

        return firstly { () -> Promise<[FetchRequest]> in
            var opts = options ?? [:]
            opts["cacheName"] = self.name

            var whereString = "cache_name = ?"
            var values: [Any?] = [self.name]

            if request.isUndefined == false {
                // If we've specified a request, we replace our existing parameters with request-specific ones.
                let request = try self.storage.getRequest(fromJSValue: request)
                (whereString, values) = try self.storage.createMatchWhere(fromRequest: request, andOptions: opts)
            }

            let requests = try DBConnectionPool.inConnection(at: try self.storage.getDBURL(), type: .cache) { db in
                return try db.select(sql: """
                    SELECT DISTINCT
                    method, request_url_no_query, request_query, request_headers
                    FROM cache_entries
                    WHERE \(whereString)
                """, values: values) { rs -> [FetchRequest] in

                    var requests: [FetchRequest] = []

                    while try rs.next() {

                        guard let method = try rs.string("method"),
                            var url = try rs.url("request_url_no_query"),
                            let headersJSON = try rs.string("request_headers") else {
                            throw ErrorMessage("Required fields did not exist")
                        }

                        let headers = try FetchHeaders.fromJSON(headersJSON)

                        if let query = try rs.string("request_query") {
                            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                                throw ErrorMessage("Could not parse URL into components")
                            }

                            components.query = query

                            guard let combinedURL = components.url else {
                                throw ErrorMessage("Could not recombine URL")
                            }

                            url = combinedURL
                        }

                        let request = FetchRequest(url: url)
                        request.headers = headers
                        request.method = method
                        requests.append(request)
                    }

                    return requests
                }
            }
            return Promise(value: requests)
        }.toJSPromiseInCurrentContext()
    }
}
