import Foundation
import JavaScriptCore

@objc protocol WebSQLTransactionExports: JSExport {
    func executeSql(_: String, _: JSValue, _: JSValue, _: JSValue)
}

@objc class WebSQLTransaction: NSObject, WebSQLTransactionExports {

    unowned let db: WebSQLDatabase

    var processingCallback: JSValue?
    var errorCallback: JSValue?
    var completeCallback: JSValue?
    let isReadOnly: Bool

    init(in db: WebSQLDatabase, isReadOnly: Bool, withCallback: JSValue, errorCallback: JSValue, completeCallback: JSValue) {
        self.db = db
        self.processingCallback = withCallback
        self.errorCallback = errorCallback
        self.completeCallback = completeCallback
        self.isReadOnly = isReadOnly
        super.init()
    }

    deinit {
        // in theory this isn't needed, but JSContext does weird stuff.
        self.processingCallback = nil
        self.errorCallback = nil
        self.completeCallback = nil
    }

    func run(_ cb: @escaping () -> Void) {

        guard let processing = self.processingCallback, let complete = self.completeCallback, let errorCB = self.errorCallback else {
            Log.error?("Callbacks do not exist")
            return
        }

        // The WebSQL API is asynchronous, so we don't want to immediately execute
        // any transaction. Instead, we push it into the runloop and wait.

        RunLoop.current.perform {
            do {

                if self.db.connection.open == false {
                    Log.error?("Cannot execute WebSQL operation - connection has been closed")
                    return
                }

                if self.isReadOnly == false {
                    try self.db.connection.beginTransaction()
                }

                processing.call(withArguments: [self])

                if self.isReadOnly == false {
                    try self.db.connection.commitTransaction()
                }
                if complete.isUndefined == false {
                    complete.call(withArguments: [])
                }
            } catch {
                Log.error?("WebSQL error: \(error)")
                do {
                    try self.db.connection.rollbackTransaction()
                } catch {
                    Log.error?("Couldn't rollback WebSQL transaction: \(error)")
                }

                if let jsError = JSValue(newErrorFromMessage: "\(error)", in: errorCB.context) {
                    errorCB.call(withArguments: [jsError])
                } else {
                    Log.error?("Could not create error instance in WebSQLTransaction callback")
                }
            }

            self.processingCallback = nil
            self.errorCallback = nil
            self.completeCallback = nil
            cb()
        }
    }

    func executeSql(_ sqlStatement: String, _ arguments: JSValue, _ callback: JSValue, _ errorCallback: JSValue) {
        do {

            guard let argumentArray = arguments.toArray() else {
                throw ErrorMessage("Could not turn arguments provided into array")
            }

            let isSelectStatement = sqlStatement
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .uppercased()
                .hasPrefix("SELECT ")

            let webResultSet: WebSQLResultSet

            if isSelectStatement == true {
                webResultSet = try self.db.connection.select(sql: sqlStatement, values: argumentArray, { res in
                    try WebSQLResultSet(resultSet: res, connection: self.db.connection)
                })
            } else {
                try self.db.connection.update(sql: sqlStatement, values: argumentArray)
                webResultSet = try WebSQLResultSet(fromUpdateIn: self.db.connection)
            }

            callback.call(withArguments: [self, webResultSet])

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
