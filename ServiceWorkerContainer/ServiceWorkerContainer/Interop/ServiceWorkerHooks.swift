//
//  ServiceWorkerHooks.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 24/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker
import PromiseKit

class ServiceWorkerHooks {

    fileprivate static func downloadAndCacheScript(id: String, url: URL) -> Promise<String> {
        return FetchSession.default.fetch(url)
            .then { res in

                // We have to download to a local file first, because we can't rely on a
                // Content-Length header always existing.

                res.internalResponse.fileDownload({ _, fileSize in
                    CoreDatabase.inConnection { db in
                        let rowID = try db.insert(sql: """
                            INSERT INTO worker_imported_scripts (worker_id, url, headers, content)
                            VALUES (?,?,?,zeroblob(?))
                        """, values: [id, url, try res.headers.toJSON(), fileSize])

                        let stream = try db.openBlobWriteStream(table: "worker_imported_scripts", column: "content", row: rowID)

                        //                        guard let inputStream = InputStream(url: url) else {
                        //                            throw ErrorMessage("Could not open input stream to local file")
                        //                        }

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

    static func importScripts(worker: ServiceWorker, scripts: [URL]) throws -> [String] {

        var scriptBodies: [String]?
        var errorEncountered: Error?

        // These operations are async, but importScripts() is not. So we need to force this
        // to return synchronously. This adds the requirement (which is good practise anyway
        // ) for us to be running our JSContxt operations on a separate thread.
        let semaphore = DispatchSemaphore(value: 0)

        CoreDatabase.inConnection { db -> Promise<[String: String]> in

            //            return Promise(value: [:])

            // first we grab scripts from our local cache

            // We need to pass in the number of parameters manually.
            let parameters = scripts.map({ _ in "?" }).joined(separator: ",")

            var params: [Any] = [worker.id]

            // Don't know why, but compiler doesn't like append contentsOf
            scripts.forEach { params.append($0) }
            //            params.append(contentsOf: scripts)

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
                    scriptBodies = try scripts.map { url in

                        guard let scriptContent = allScripts[url.absoluteString] else {
                            throw ErrorMessage("Imported script is still not in dictionary")
                        }

                        return scriptContent
                    }
                }
        }
        .catch { error in
            errorEncountered = error
        }
        .always {
            // Resume
            semaphore.signal()
        }

        // now we wait until our async operation has completed.
        _ = semaphore.wait(timeout: .distantFuture)

        if let error = errorEncountered {
            throw error
        }

        if let bodies = scriptBodies {
            return bodies
        } else {
            throw ErrorMessage("No errir was encountered, but script bodies are not populated")
        }
    }

    static func loadContent(worker: ServiceWorker) -> String {

        var script = ""
        do {
            script = try CoreDatabase.inConnection { db in
                return try db.select(sql: "SELECT content FROM workers WHERE worker_id = ?", values: [worker.id]) { resultSet in
                    if try resultSet.next() == false {
                        throw ErrorMessage("Worker does not exist")
                    }
                    guard let content = try resultSet.string("content") else {
                        throw ErrorMessage("Worker does not have any content")
                    }
                    return content
                }
            }
        } catch {
            // This seems weird, but there's no other easy way to throw an error here.
            script = "throw new Error('\(String(describing: error))')"
        }

        return script
    }
}
