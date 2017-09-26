import Foundation
import JavaScriptCore

@objc public protocol ServiceWorkerRegistrationProtocol {
    func showNotification(_: JSValue) -> JSValue
    var id: String { get }
    var scope: URL { get }
    var active: ServiceWorker? { get }
    var waiting: ServiceWorker? { get }
    var installing: ServiceWorker? { get }
    var redundant: ServiceWorker? { get }
}
