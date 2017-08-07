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
        return FetchOperation.fetch(url)
            .then { res in

                // This is kind of convoluted, but two reasons for us to stream into DB
                // then immediately select it back again:
                // 1. if we did res.text() we wouldn't be able to get the hash
                // 2. if we did res.data() then converted to string after hashing,
                //    we'd use more memory

                let lengthString = res.headers.get("Content-Length")
                if lengthString == nil {
                    throw ErrorMessage("Content-Length header must be provided")
                }

                let length = Int64(lengthString!)
                if length == nil {
                    throw ErrorMessage("Content-Length header must be a number")
                }

                return CoreDatabase.inConnection { db in
                    let rowID = try db.insert(sql: """
                        INSERT INTO worker_imported_scripts (worker_id, url, headers, content)
                        VALUES (?,?,?,zeroblob(?))
                    """, values: [id, url, try res.headers.toJSON(), length!])

                    let stream = db.openBlobWriteStream(table: "worker_imported_scripts", column: "content", row: rowID)
                    let reader = try res.getReader()
                    return stream.pipeReadableStream(stream: reader)
                        .then { hash -> String in

                            // Now we update the hash for the script
                            try db.update(sql: "UPDATE worker_imported_scripts SET content_hash = ? WHERE worker_id = ?", values: [hash, id])

                            // Having done all this, we now pull the text directly back out
                            return try db.select(sql: "SELECT content FROM worker_imported_scripts WHERE worker_id = ?", values: [id]) { resultSet in
                                if resultSet.next() == false {
                                    throw ErrorMessage("Somehow cannot retreive the script we just inserted")
                                }
                                return try resultSet.string("content")!
                            }
                        }
                }
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

            return try db.select(sql: "SELECT url, content FROM worker_imported_scripts WHERE worker_id = ? AND url IN (\(parameters))", values: params) {
                resultSet in

                var scriptBodies: [String: String] = [:]

                while resultSet.next() {
                    let url = try resultSet.string("url")!
                    scriptBodies[url] = try resultSet.string("content")!
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
                    scriptBodies = scripts.map { allScripts[$0.absoluteString]! }
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

        if errorEncountered != nil {
            throw errorEncountered!
        }

        return scriptBodies!
    }

    static func loadContent(worker: ServiceWorker) -> String {

        var script = ""
        do {
            script = try CoreDatabase.inConnection { db in
                return try db.select(sql: "SELECT content FROM workers WHERE worker_id = ?", values: [worker.id]) { resultSet in
                    if resultSet.next() == false {
                        throw ErrorMessage("Worker does not exist")
                    }
                    return try resultSet.string("content")!
                }
            }
        } catch {
            // This seems weird, but there's no other easy way to throw an error here.
            script = "throw new Error('\(String(describing: error))')"
        }

        return script
    }
}
