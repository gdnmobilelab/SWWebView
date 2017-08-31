//
//  WebSQLTransaction.swift
//  ServiceWorker
//
//  Created by alastair.coote on 03/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol WebSQLTransactionExports: JSExport {
    func executeSql(_: String, _: [JSValue], _: JSValue, _: JSValue)
}

@objc class WebSQLTransaction: NSObject, WebSQLTransactionExports {

    unowned let connection: SQLiteConnection

    init(in connection: SQLiteConnection, withCallback: JSValue, completeCallback: JSValue) {
        self.connection = connection
        super.init()

        // The WebSQL API seems kind of confusing - async seems kind of pointless because
        // the withCallback callback doesn't have a callback itself -  it is executed
        // synchronously. But hey, we'll implement it.

        do {
            try self.connection.beginTransaction()

            withCallback.call(withArguments: [self])

            try self.connection.commitTransaction()
            completeCallback.call(withArguments: [])
        } catch {
            do {
                try self.connection.rollbackTransaction()
            } catch {
                Log.error?("Couldn't rollback WebSQL transaction: \(error)")
            }

            if let jsError = JSValue(newErrorFromMessage: "\(error)", in: completeCallback.context) {
                completeCallback.call(withArguments: [jsError])
            } else {
                Log.error?("Could not create error instance in WebSQLTransaction callback")
            }
            
        }
    }

    func executeSql(_ sqlStatement: String, _ arguments: [JSValue], _ callback: JSValue, _ errorCallback: JSValue) {

        let asObjects: [Any] = arguments.map { jsVal in
            return jsVal.toObject()
        }

        do {
            let webResultSet = try self.connection.select(sql: sqlStatement, values: asObjects, { res in
                try WebSQLResultSet(resultSet: res, connection: self.connection)
            })
            callback.call(withArguments: [webResultSet])
        } catch {
            Log.error?("Error when processing WebSQL statement: \(error)")
            if let err = JSValue(newErrorFromMessage: "\(error)", in: errorCallback.context) {
                errorCallback.call(withArguments: [err])
            } else {
                Log.error?("Could not create error instance in WebSQLTransaction callback")
            }
            
        }
    }
}
