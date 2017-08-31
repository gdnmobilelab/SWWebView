//
//  WorkerInstances.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 24/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker
import PromiseKit

/// We keep track of the workers currently in use, so that we don't ever duplicate them.
public class WorkerFactory {

    fileprivate let workerStorage = NSHashTable<ServiceWorker>.weakObjects()
    public var clientsDelegate: WorkerClientsProtocol? = nil
    
    public init() {
    }
    
    func get(id: String, withRegistration registration: ServiceWorkerRegistration) throws -> ServiceWorker {
        let workerWanted = workerStorage.allObjects.filter { $0.id == id }
        
        guard let delegate = self.clientsDelegate else {
            throw ErrorMessage("Must have a clientsDelegate set")
        }

        if let existingWorker = workerWanted.first {
            
            guard let existingRegistration = existingWorker.registration as? ServiceWorkerRegistration else {
                throw ErrorMessage("Worker has been created with a different registration type")
            }
            
            if existingRegistration != registration {
                throw ErrorMessage("Existing worker does have the correct registration")
            }
            
            return existingWorker
        }

        let dbWorker = try CoreDatabase.inConnection { db -> ServiceWorker in
            return try db.select(sql: "SELECT registration_id, url, install_state FROM workers WHERE worker_id = ?", values: [id]) { (resultSet) -> ServiceWorker in
                if resultSet.next() == false {
                    throw ErrorMessage("Worker does not exist")
                }

                let registrationId = try resultSet.string("registration_id")!

                if registration.id != registrationId {
                    throw ErrorMessage("Trying to create a worker with the wrong registration")
                }
                
                let state = ServiceWorkerInstallState(rawValue: try resultSet.string("install_state")!)!
                
                let implementations = WorkerImplementations(registration: registration, clients: delegate, importScripts: ServiceWorkerHooks.importScripts)
                
                return ServiceWorker(id: id, url: try resultSet.url("url")!, implementations: implementations, state: state, loadContent: ServiceWorkerHooks.loadContent)
            }
        }

        workerStorage.add(dbWorker)

        return dbWorker
    }
    
    func update(worker:ServiceWorker, toInstallState newState: ServiceWorkerInstallState) throws {
        try CoreDatabase.inConnection { db in
            try db.update(sql: "UPDATE workers SET install_state = ? WHERE worker_id = ?", values: [newState.rawValue, worker.id])
        }
        worker.state = newState
    }
    
    func update(worker:ServiceWorker, setScriptResponse res: FetchResponseProtocol) -> Promise<Void> {
        
        return CoreDatabase.inConnection { db in
                
            // We should only ever update the content of a worker once - any changes
            // should be reflected in a new worker, not updating the existing one. So
            // first, we check that we haven't already set content on this worker.
            
            return try db.select(sql: """
                SELECT
                    CASE content WHEN NULL 0 ELSE 1 END AS num
                FROM workers
                WHERE worker_id = ?
            """, values: [worker.id]) { rs in
                if rs.next() != true {
                    throw ErrorMessage("Existing content DB check didn't work")
                }
                let num = try rs.int("num")
                
                if num != 0 {
                    throw ErrorMessage("This worker appears to already have content in it. Content can only be set once.")
                }
                
                return Promise(value: ())
            }
            
     
        }
            .then {
                // We can't rely on the Content-Length header as some places don't send one. But SQLite requires
                // you to establish a blob with length. So instead, we are streaming the download to disk, then
                // manually streaming into the DB when we have the length available.
                
                return res.internalResponse.fileDownload(withDownload: { url in
                    
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let size = fileAttributes[.size] as! Int64
                    
                    // ISSUE: do we update the URL here, if the response was redirected? If we do, it'll mean
                    // future update() calls won't check the original URL, which feels wrong. But having this
                    // URL next to content from another URL also feels wrong.
                    
                    return CoreDatabase.inConnection { db -> Promise<Void> in
                        try db.update(sql: """
                    UPDATE workers SET
                        headers = ?,
                        content = zeroblob(?)
                    WHERE
                        worker_id = ?
                """, values: [
                    try res.headers.toJSON(),
                    size,
                    worker.id,
                    ])
                        
                    let rowID = try db.select(sql: "SELECT rowid FROM workers WHERE worker_id = ?", values: [worker.id]) { rs -> Int64 in
                        _ = rs.next()
                        return try rs.int64("rowid")!
                    }
                    
                    let inputStream = InputStream(url: url)!
                    let writeStream = db.openBlobWriteStream(table: "workers", column: "content", row: rowID)
                    
                    return writeStream.pipeReadableStream(stream: ReadableStream.fromInputStream(stream: inputStream, bufferSize: 32768)) // chunks of 32KB. No idea what is best.
                        .then { hash -> Void in
                            
                            try db.update(sql: "UPDATE workers SET content_hash = ? WHERE worker_id = ?", values: [hash, worker.id])
                    }
                }
                
                
                
            })
        }
        
        
    }
    
    /// Special case, primarily used in deleting an installing worker where the fetch failed
    func delete(worker: ServiceWorker) throws {
        try CoreDatabase.inConnection { db in
            try db.update(sql: "DELETE FROM workers WHERE worker_id = ?", values: [worker.id])
        }
        
        // just make sure that nothing will try to access this worker
        self.workerStorage.remove(worker)
    }
    
    func isByteIdentical(_ workerOne: ServiceWorker, _ workerTwo: ServiceWorker) throws -> Bool {
        
        return try CoreDatabase.inConnection { db in
            return try db.select(sql: """
            SELECT CASE WHEN
                    (SELECT hash FROM workers WHERE worker_id = ?) as one
                =
                    (SELECT hash FROM workers WHERE worker_id = ?) as two
                THEN 1 ELSE 0
            END as isIdentical
            """, values: [workerOne.id, workerTwo.id]) {rs in
                
                if rs.next() == false {
                    throw ErrorMessage("Could not find both worker IDs")
                }
                
                guard let isIdentical = try rs.int("isIdentical") else {
                    throw ErrorMessage("DB check for byte identical failed")
                }
                
                return isIdentical == 1
                
            }
            
        }
    }
    
    func getUpdateRequest(forExistingWorker worker: ServiceWorker) throws -> FetchRequest {
        
        return try CoreDatabase.inConnection { db in
            
            let request = FetchRequest(url: worker.url)
            
            let existingHeaders = try db.select(sql: "SELECT headers FROM workers WHERE worker_id = ?", values: [worker.id]) { resultSet -> FetchHeaders? in
                
                if resultSet.next() == false {
                    return nil
                }
                
                let jsonString = try resultSet.string("headers")!
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
