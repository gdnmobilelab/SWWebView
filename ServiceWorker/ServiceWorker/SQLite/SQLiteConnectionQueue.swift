//
//  SQLiteConnectionQueue.swift
//  ServiceWorker
//
//  Created by alastair.coote on 16/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

/// We don't want to end up with multiple connections to the same database, as SQLite
/// doesn't like you modifying a table from two different connections simultaneously.
class SQLiteConnectionQueue {
    
    struct ActiveConnection {
        let connection: SQLiteConnection
        var activeSessionCount:Int
    }
    
    fileprivate static var poolQueue = DispatchQueue(label: "SQLiteConnectionQueue")
    fileprivate static var currentOpenConnections: [String:ActiveConnection] = [:]
    
    
    /// Run operations on a database connection, using our internal pool
    public static func withConnection<T>(to url: URL, _ callback: @escaping (SQLiteQueuedSession) throws -> Promise<T>) -> Promise<T> {
        
        return Promise(value: ())
            // We run all of these operations on the pool queue so that we can ensure we don't have two
            // add/remove operations running simultaneously
            .then(on: self.poolQueue, execute: {
                var active = self.currentOpenConnections[url.absoluteString]
                if active == nil {
                    // If we don't have an active connection for this URL, we create one and store it
                    active = ActiveConnection(connection: try SQLiteConnection(url), activeSessionCount: 1)
                    self.currentOpenConnections[url.absoluteString] = active
                } else {
                    // Otherwise, we increment the number of active sessions using this connection.
                    active!.activeSessionCount += 1
                }
                
                // At this point we move off our pool queue and execute whatever promise stuff we want asynchronously.
                let session = SQLiteQueuedSession(with: active!.connection)
                return try callback(session)
                    .always(on: self.poolQueue, execute: {
                        
                        // Then we jump back onto our pool queue again.
                        
                        // No matter whether promise succeeds or fails, we want to invalidate the session
                        // and close the DB connection, if no-one else is using it.
                        
                        session.invalidate()
                        active!.activeSessionCount -= 1
                        
                        if active!.activeSessionCount == 0 {
                            do {
                                try active!.connection.close()
                            } catch {
                                Log.error?("Could not close DB connection after using it: \(error)")
                            }
                            self.currentOpenConnections.removeValue(forKey: url.absoluteString)
                        }
                    })
            })
        
            
        }
    
    public static func withConnection<T>(to url: URL, _ callback: @escaping (SQLiteQueuedSession) throws -> T) -> Promise<T> {
        
        let promiseCallback = { (session:SQLiteQueuedSession) in
            return Promise(value: try callback(session))
        }
        
        return self.withConnection(to: url, promiseCallback)
    }
        
    
}
