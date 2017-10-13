import Foundation

/// The bridge between the service worker and the webviews in the app. Allows a worker to open a window
/// claim clients, etc. Based on: https://developer.mozilla.org/en-US/docs/Web/API/Clients
@objc public protocol ServiceWorkerClientsDelegate {

    // These are all optional, but in retrospect, I'm not totally sure why.

    @objc optional func clients(_: ServiceWorker, getById: String, _ callback: (Error?, ClientProtocol?) -> Void)
    @objc optional func clients(_: ServiceWorker, matchAll: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void)
    @objc optional func clients(_: ServiceWorker, openWindow: URL, _ cb: (Error?, ClientProtocol?) -> Void)
    @objc optional func clientsClaim(_: ServiceWorker, _ cb: (Error?) -> Void)
}
