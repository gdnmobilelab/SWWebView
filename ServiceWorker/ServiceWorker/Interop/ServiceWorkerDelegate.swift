import Foundation

@objc public protocol ServiceWorkerDelegate {

    @objc func serviceWorker(_: ServiceWorker, importScripts: [URL], _ callback: @escaping (_: Error?, _: [String]?) -> Void)
    @objc func serviceWorkerGetDomainStoragePath(_: ServiceWorker) throws -> URL
    @objc func serviceWorkerGetScriptContent(_: ServiceWorker) throws -> String
    @objc func getCoreDatabaseURL() -> URL
}
