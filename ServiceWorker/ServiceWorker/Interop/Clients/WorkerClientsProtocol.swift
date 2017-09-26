import Foundation
import JavaScriptCore
import PromiseKit

@objc public protocol WorkerCsdflientsProtocol {
    func get(id: String, worker: ServiceWorker, _ cb: (Error?, ClientProtocol?) -> Void)
    func matchAll(options: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void)
    func openWindow(_: URL, _ cb: (Error?, ClientProtocol?) -> Void)
    func claim(_ cb: (Error?) -> Void)
}
