import Foundation
import JavaScriptCore

@objc protocol ServiceWorkerGlobalScopeDelegate {
    func importScripts(urls: [URL]) throws
    func openWebSQLDatabase(name: String) throws -> WebSQLDatabase
    func fetch(_: JSValue) -> JSValue?
}
