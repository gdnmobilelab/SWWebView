//
//  WebSQLDatabase.swift
//  ServiceWorker
//
//  Created by alastair.coote on 02/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol WebSQLDatabaseExports : JSExport {
    func transaction(_ : JSValue, _: JSValue)
}


@objc class WebSQLDatabase : NSObject, WebSQLDatabaseExports {
    
    let connection: SQLiteConnection
    
    init(at path: URL) throws {
        self.connection = try SQLiteConnection(path)
    }
    
    func transaction(_ withCallback: JSValue, _ completeCallback: JSValue) {
        _ = WebSQLTransaction(in: self.connection, withCallback: withCallback, completeCallback: completeCallback)
    }
    
    static func createOpenDatabaseFunction(for url: URL) -> AnyObject {
        
        let escapedOrigin = url.host!.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        
        let open: @convention(block) (JSValue, String, Int, JSValue?) -> WebSQLDatabase? = { name, version, size, callback in
            
            // Since we're only using this so that IndexedDBShim can use it, we can skip some unnecessary
            // features - for instance, it doesn't use DB versions, so we'll ignore that.
            
            // name is a JSValue just so that we can grab a reference to its JSContext if we need
            // to throw an error.
            
            if ServiceWorker.storageURL == nil {
                let errorText = "Tried to create a WebSQL database without setting the storage URL for ServiceWorker"
                Log.error?(errorText)
                name.context.exception = JSValue(newErrorFromMessage: errorText, in: name.context)
            }
            
            
            let escapedName = name.toString().addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            
            let dbDirectory = ServiceWorker.storageURL!
                .appendingPathComponent(escapedOrigin, isDirectory: true)
                .appendingPathComponent("websql", isDirectory: true)
                
                
            let dbURL = dbDirectory
                .appendingPathComponent(escapedName)
                .appendingPathExtension("sqlite")
            
            do {
                if FileManager.default.fileExists(atPath: dbDirectory.path) == false {
                    try FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                
                
                let db = try WebSQLDatabase(at: dbURL)
                return db
            } catch {
                let err = JSValue(newErrorFromMessage: "\(error)", in: name.context)
                name.context.exception = err
                Log.error?("\(error)")
                return nil
            }
            
        }
        
        return unsafeBitCast(open, to: AnyObject.self)
        
    }
    
}
