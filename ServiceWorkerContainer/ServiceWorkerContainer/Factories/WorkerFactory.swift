import Foundation
import ServiceWorker
import PromiseKit

/// We keep track of the workers currently in use, so that we don't ever duplicate them.
public class WorkerFactory {

    fileprivate let workerStorage = NSHashTable<ServiceWorker>.weakObjects()
    public var clientsDelegateProvider: ServiceWorkerClientsDelegate?
    public var serviceWorkerDelegateProvider: ServiceWorkerDelegate?
    public var cacheStorageProvider: CacheStorageProviderDelegate?

    public init() {
    }

    func getCoreDBPath() throws -> URL {
        guard let coreStorage = self.serviceWorkerDelegateProvider?.getCoreDatabaseURL() else {
            throw ErrorMessage("Must have a ServiceWorkerDelegate specified")
        }

        return coreStorage
    }

    public func get(id: String, withRegistration registration: ServiceWorkerRegistration) throws -> ServiceWorker {

        let dbURL = try self.getCoreDBPath()

        let workerWanted = workerStorage.allObjects.filter { $0.id == id }

        if let existingWorker = workerWanted.first {

            if existingWorker.registration?.id != registration.id {
                throw ErrorMessage("Existing worker has a different registration")
            }

            return existingWorker
        }

        let dbWorker = try DBConnectionPool.inConnection(at: dbURL, type: .core) { db -> ServiceWorker in
            return try db.select(sql: "SELECT registration_id, url, install_state FROM workers WHERE worker_id = ?", values: [id]) { (resultSet) -> ServiceWorker in

                if try resultSet.next() == false {
                    throw ErrorMessage("Worker does not exist")
                }

                guard let registrationId = try resultSet.string("registration_id") else {
                    throw ErrorMessage("Could not fetch worker ID")
                }

                if registration.id != registrationId {
                    throw ErrorMessage("Trying to create a worker with the wrong registration")
                }

                guard let rawState = try resultSet.string("install_state") else {
                    throw ErrorMessage("Worker does not have an install state in the database")
                }

                guard let state = ServiceWorkerInstallState(rawValue: rawState) else {
                    throw ErrorMessage("Worker has an invalid install state")
                }

                guard let workerURL = try resultSet.url("url") else {
                    throw ErrorMessage("Service worker does not have a valid URL")
                }

                let worker = ServiceWorker(id: id, url: workerURL, state: state)
                worker.clientsDelegate = self.clientsDelegateProvider
                worker.delegate = self.serviceWorkerDelegateProvider
                if let cacheStorage = self.cacheStorageProvider {
                    worker.cacheStorage = try cacheStorage.createCacheStorage(worker)
                }
                worker.registration = registration

                if let storageProvider = self.cacheStorageProvider {
                    worker.cacheStorage = try storageProvider.createCacheStorage(worker)
                }

                return worker
            }
        }

        workerStorage.add(dbWorker)

        return dbWorker
    }

    func create(for url: URL, in registration: ServiceWorkerRegistration) throws -> ServiceWorker {

        let dbURL = try self.getCoreDBPath()

        let newWorkerID = UUID().uuidString

        try DBConnectionPool.inConnection(at: dbURL, type: .core) { db in
            _ = try db.insert(sql: """
                INSERT INTO workers
                    (worker_id, url, install_state, registration_id, content)
                VALUES
                    (?,?,?,?,NULL)
            """, values: [
                newWorkerID,
                url,
                ServiceWorkerInstallState.installing.rawValue,
                registration.id
            ])
        }

        let worker = try self.get(id: newWorkerID, withRegistration: registration)

        return worker
    }

    func update(worker: ServiceWorker, toInstallState newState: ServiceWorkerInstallState) throws {
        try DBConnectionPool.inConnection(at: self.getCoreDBPath(), type: .core) { db in
            try db.update(sql: "UPDATE workers SET install_state = ? WHERE worker_id = ?", values: [newState.rawValue, worker.id])
        }
        worker.state = newState
    }

    func update(worker: ServiceWorker, setScriptResponse res: FetchResponseProtocol) -> Promise<Void> {

        return firstly {
            try DBConnectionPool.inConnection(at: self.getCoreDBPath(), type: .core) { db -> Promise<Void> in

                // We should only ever update the content of a worker once - any changes
                // should be reflected in a new worker, not updating the existing one. So
                // first, we check that we haven't already set content on this worker.

                try db.select(sql: """
                    SELECT
                        CASE WHEN content IS NULL THEN 0 ELSE 1 END AS num
                    FROM workers
                    WHERE worker_id = ?
                """, values: [worker.id]) { rs in
                    if try rs.next() != true {
                        throw ErrorMessage("Existing content DB check didn't work")
                    }
                    let num = try rs.int("num")

                    if num != 0 {
                        throw ErrorMessage("This worker appears to already have content in it. Content can only be set once.")
                    }

                    return Promise(value: ())
                }
            }
        }
        .then {
            // We can't rely on the Content-Length header as some places don't send one. But SQLite requires
            // you to establish a blob with length. So instead, we are streaming the download to disk, then
            // manually streaming into the DB when we have the length available.

            res.internalResponse.fileDownload({ url, fileSize in

                // ISSUE: do we update the URL here, if the response was redirected? If we do, it'll mean
                // future update() calls won't check the original URL, which feels wrong. But having this
                // URL next to content from another URL also feels wrong.

                try DBConnectionPool.inConnection(at: self.getCoreDBPath(), type: .core) { db -> Promise<Void> in
                    try db.update(sql: """
                        UPDATE workers SET
                            headers = ?,
                            content = zeroblob(?)
                        WHERE
                            worker_id = ?
                    """, values: [
                        try res.headers.toJSON(),
                        fileSize,
                        worker.id
                    ])

                    let rowID = try db.select(sql: "SELECT rowid FROM workers WHERE worker_id = ?", values: [worker.id]) { rs -> Int64 in

                        if try rs.next() == false {
                            throw ErrorMessage("Could not find service worker we're importing a script to in the database")
                        }

                        guard let rowid = try rs.int64("rowid") else {
                            throw ErrorMessage("Could not get row ID for service worker")
                        }

                        return rowid
                    }

                    let writeStream = try db.openBlobWriteStream(table: "workers", column: "content", row: rowID)

                    guard let fileStream = InputStream(fileAtPath: url.path) else {
                        throw ErrorMessage("Could not open stream to temporary file")
                    }

                    return StreamPipe.pipeSHA256(from: fileStream, to: writeStream, bufferSize: 32768, dispatchQueue: DispatchQueue.default)
                        .then { hash in
                            try db.update(sql: "UPDATE workers SET content_hash = ? WHERE worker_id = ?", values: [hash, worker.id])
                        }
                }

            })
        }
    }

    /// Special case, primarily used in deleting an installing worker where the fetch failed
    func delete(worker: ServiceWorker) throws {
        try DBConnectionPool.inConnection(at: self.getCoreDBPath(), type: .core) { db in
            try db.update(sql: "DELETE FROM workers WHERE worker_id = ?", values: [worker.id])
        }

        // just make sure that nothing will try to access this worker
        self.workerStorage.remove(worker)
    }

    func isByteIdentical(_ workerOne: ServiceWorker, _ workerTwo: ServiceWorker) throws -> Bool {
        return try DBConnectionPool.inConnection(at: self.getCoreDBPath(), type: .core) { db in
            try db.select(sql: """

                SELECT CASE WHEN one.content_hash = two.content_hash THEN 1 ELSE 0 END as isSame
                FROM workers as one,
                    workers as two
                WHERE one.worker_id = ?
                AND two.worker_id = ?

            """, values: [workerOne.id, workerTwo.id]) { rs in

                if try rs.next() == false {
                    throw ErrorMessage("Could not find both worker IDs")
                }

                guard let isSame = try rs.int("isSame") else {
                    throw ErrorMessage("Hash comparison failed")
                }

                return isSame == 1
            }
        }
    }

    func getUpdateRequest(forExistingWorker worker: ServiceWorker) throws -> FetchRequest {

        return try DBConnectionPool.inConnection(at: self.getCoreDBPath(), type: .core) { db in

            let request = FetchRequest(url: worker.url)

            let existingHeaders = try db.select(sql: "SELECT headers FROM workers WHERE worker_id = ?", values: [worker.id]) { resultSet -> FetchHeaders? in

                if try resultSet.next() == false {
                    return nil
                }

                guard let jsonString = try resultSet.string("headers") else {
                    throw ErrorMessage("Database row does not contain response headers")
                }

                return try FetchHeaders.fromJSON(jsonString)
            }

            // We attempt to use Last-Modified and ETag headers to minimise the amount of code we're downloading
            // as part of this update process. If we are updating an existing worker, we grab the headers seen at
            // the time.

            if let etag = existingHeaders?.get("ETag") {
                request.headers.append("If-None-Match", etag)
            }
            if let lastMod = existingHeaders?.get("Last-Modified") {
                request.headers.append("If-Modified-Since", lastMod)
            }

            return request
        }
    }
}
