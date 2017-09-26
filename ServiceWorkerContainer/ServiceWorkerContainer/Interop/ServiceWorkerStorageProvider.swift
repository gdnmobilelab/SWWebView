import Foundation
import ServiceWorker
import PromiseKit

public class ServiceWorkerStorageProvider: ServiceWorkerDelegate {

    let storageURL: URL

    public init(storageURL: URL) {
        self.storageURL = storageURL
    }

    public func getCoreDatabaseURL() -> URL {
        return self.storageURL.appendingPathComponent("core.db")
    }

    public func serviceWorker(_ worker: ServiceWorker, importScripts scripts: [URL], _ callback: @escaping (Error?, [String]?) -> Void) {
        DBConnectionPool.inConnection(at: self.getCoreDatabaseURL(), type: .core) { db -> Promise<[String: String]> in

            // first we grab scripts from our local cache

            // We need to pass in the number of parameters manually.
            let parameters = scripts.map({ _ in "?" }).joined(separator: ",")

            var params: [Any] = [worker.id]

            // Don't know why, but compiler doesn't like append contentsOf
            scripts.forEach { params.append($0) }

            return try db.select(sql: "SELECT url, content FROM worker_imported_scripts WHERE worker_id = ? AND url IN (\(parameters))", values: params) { resultSet in

                var scriptBodies: [String: String] = [:]

                while try resultSet.next() {
                    guard let url = try resultSet.string("url"), let content = try resultSet.string("content") else {
                        throw ErrorMessage("An imported script was missing a URL or content")
                    }
                    scriptBodies[url] = content
                }

                return Promise(value: scriptBodies)
            }
        }
        .then { cachedScripts -> Promise<Void> in

            var allScripts = cachedScripts

            // then we grab and cache any scripts not already locally cached

            let scriptsToFetch = scripts.filter { cachedScripts.index(forKey: $0.absoluteString) == nil }

            let fetchPromises = scriptsToFetch.map { url in
                return self.downloadAndCacheScript(id: worker.id, url: url)
                    .then { body -> Void in
                        allScripts[url.absoluteString] = body
                    }
            }

            return when(fulfilled: fetchPromises)
                .then { _ -> Void in

                    let scriptBodies = try scripts.map { url -> String in

                        guard let scriptContent = allScripts[url.absoluteString] else {
                            throw ErrorMessage("Imported script is still not in dictionary")
                        }

                        return scriptContent
                    }

                    callback(nil, scriptBodies)
                }
        }
        .catch { error in
            callback(error, nil)
        }
    }

    fileprivate func downloadAndCacheScript(id: String, url: URL) -> Promise<String> {
        return FetchSession.default.fetch(url)
            .then { res in

                // We have to download to a local file first, because we can't rely on a
                // Content-Length header always existing.

                res.internalResponse.fileDownload({ _, fileSize in

                    DBConnectionPool.inConnection(at: self.getCoreDatabaseURL(), type: .core) { db in
                        let rowID = try db.insert(sql: """
                            INSERT INTO worker_imported_scripts (worker_id, url, headers, content)
                            VALUES (?,?,?,zeroblob(?))
                        """, values: [id, url, try res.headers.toJSON(), fileSize])

                        let stream = try db.openBlobWriteStream(table: "worker_imported_scripts", column: "content", row: rowID)
                        let readableStream = try ReadableStream.fromLocalURL(url, bufferSize: 8192)

                        return stream.pipeReadableStream(stream: readableStream)
                            .then { hash -> String in

                                // Now we update the hash for the script
                                try db.update(sql: "UPDATE worker_imported_scripts SET content_hash = ? WHERE worker_id = ?", values: [hash, id])

                                // Having done all this, we now pull the text directly back out
                                return try db.select(sql: "SELECT content FROM worker_imported_scripts WHERE worker_id = ?", values: [id]) { resultSet in

                                    if try resultSet.next() == false {
                                        throw ErrorMessage("Somehow cannot retreive the script we just inserted")
                                    }

                                    guard let content = try resultSet.string("content") else {
                                        throw ErrorMessage("Could not get content of script from DB")
                                    }

                                    return content
                                }
                            }
                    }
                })
            }
    }

    public func serviceWorkerGetScriptContent(_ worker: ServiceWorker) throws -> String {

        return try DBConnectionPool.inConnection(at: self.getCoreDatabaseURL(), type: .core) { db in

            try db.select(sql: "SELECT content FROM workers WHERE worker_id = ?", values: [worker.id]) { rs in

                if try rs.next() == false {
                    throw ErrorMessage("Worker does not exist in database")
                }

                guard let content = try rs.string("content") else {
                    throw ErrorMessage("Worker does not have content set")
                }

                return content
            }
        }
    }

    public func serviceWorker(_: ServiceWorker, getStoragePathForDomain domain: String) -> URL {
        return self.storageURL
            .appendingPathComponent("domains", isDirectory: true)
            .appendingPathComponent(domain, isDirectory: true)
    }
}
