import Foundation

@objc protocol ServiceWorkerGlobalScopeDelegate {
    func importScripts(urls: [URL]) throws
    func openWebSQLDatabase(name: String) throws -> WebSQLDatabase
}
