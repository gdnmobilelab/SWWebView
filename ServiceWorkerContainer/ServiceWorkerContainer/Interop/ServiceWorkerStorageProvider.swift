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

    public func serviceWorker(_ worker: ServiceWorker, importScript script: URL, _ callback: @escaping (Error?, String?) -> Void) {

        var existing: String?

        do {
            existing = try DBConnectionPool.inConnection(at: self.getCoreDatabaseURL(), type: .core) { db -> String? in

                return try db.select(sql: "SELECT content FROM worker_imported_scripts WHERE worker_id = ? AND url = ?", values: [script]) { resultSet in

                    if try resultSet.next() {
                        guard let content = try resultSet.string("content") else {
                            throw ErrorMessage("An imported script was missing a URL or content")
                        }
                        return content
                    } else {
                        return nil
                    }
                }
            }

        } catch {
            callback(error, nil)
            return
        }

        if let existingContent = existing {
            callback(nil, existingContent)
            return
        }

        self.downloadAndCacheScript(id: worker.id, url: script)
            .then { body in
                callback(nil, body)
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

                res.internalResponse.fileDownload({ fileURL, fileSize in

                    DBConnectionPool.inConnection(at: self.getCoreDatabaseURL(), type: .core) { db in
                        let rowID = try db.insert(sql: """
                            INSERT INTO worker_imported_scripts (worker_id, url, headers, content)
                            VALUES (?,?,?,zeroblob(?))
                        """, values: [id, url, try res.headers.toJSON(), fileSize])

                        let stream = try db.openBlobWriteStream(table: "worker_imported_scripts", column: "content", row: rowID)

                        guard let fileStream = InputStream(url: fileURL) else {
                            throw ErrorMessage("Could not create input stream for local file")
                        }

                        return StreamPipe.pipeSHA256(from: fileStream, to: stream, bufferSize: 1024)
                            .then { hash -> String in

                                // Now we update the hash for the script
                                try db.update(sql: "UPDATE worker_imported_scripts SET content_hash = ? WHERE worker_id = ? AND url = ?", values: [hash, id, url])

                                // Having done all this, we now pull the text directly back out
                                return try db.select(sql: "SELECT content FROM worker_imported_scripts WHERE worker_id = ? AND url = ?", values: [id, url]) { resultSet in

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

    public func serviceWorkerGetDomainStoragePath(_ worker: ServiceWorker) throws -> URL {
        guard let host = worker.url.host else {
            throw ErrorMessage("Cannot get storage URL for worker with no host")
        }
        return self.storageURL
            .appendingPathComponent("domains", isDirectory: true)
            .appendingPathComponent(host, isDirectory: true)
    }
}
