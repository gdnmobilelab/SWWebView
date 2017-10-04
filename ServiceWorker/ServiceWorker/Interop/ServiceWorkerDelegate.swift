import Foundation

@objc public protocol ServiceWorkerDelegate {

    @objc func serviceWorker(_: ServiceWorker, importScript: URL, _ callback: @escaping (Error?, String?) -> Void)
    @objc func serviceWorkerGetDomainStoragePath(_: ServiceWorker) throws -> URL
    @objc func serviceWorkerGetScriptContent(_: ServiceWorker) throws -> String
    @objc func getCoreDatabaseURL() -> URL
}
