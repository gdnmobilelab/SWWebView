import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol FetchEventExports: JSExport {
    func respondWith(_: JSValue)
}

@objc public class FetchEvent: Event, FetchEventExports {

    let extender = EventPromiseExtender()

    func respondWith(_ val: JSValue) {
        self.extender.add(val)
    }

    public func resolve(in worker: ServiceWorker) -> Promise<JSValue> {

        return self.extender.resolve(in: worker)
    }
}
