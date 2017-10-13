import Foundation
import JavaScriptCore

/// We don't provide an implementation of ServiceWorkerRegistration in this project, but this
/// protocol is a hook to add one to a worker. Based on:
/// https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration
@objc public protocol ServiceWorkerRegistrationProtocol {
    func showNotification(_: JSValue) -> JSValue
    var id: String { get }
    var scope: URL { get }
    var active: ServiceWorker? { get }
    var waiting: ServiceWorker? { get }
    var installing: ServiceWorker? { get }
    var redundant: ServiceWorker? { get }
}
