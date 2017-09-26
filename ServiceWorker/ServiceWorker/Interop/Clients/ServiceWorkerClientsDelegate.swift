import Foundation

@objc public protocol ServiceWorkerClientsDelegate {

    @objc optional func clients(_: ServiceWorker, getById: String, _ callback: (Error?, ClientProtocol?) -> Void)
    @objc optional func clients(_: ServiceWorker, matchAll: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void)
    @objc optional func clients(_: ServiceWorker, openWindow: URL, _ cb: (Error?, ClientProtocol?) -> Void)
    @objc optional func clientsClaim(_: ServiceWorker, _ cb: (Error?) -> Void)
}
