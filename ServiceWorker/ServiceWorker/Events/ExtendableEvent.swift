import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol ExtendableEventExports: JSExport {
    func waitUntil(_: JSValue)
}

@objc public class ExtendableEvent: Event, ExtendableEventExports {

    let extender = EventPromiseExtender()

    func waitUntil(_ val: JSValue) {

        self.extender.add(val)
    }

    public func resolve(in worker: ServiceWorker) -> Promise<Void> {

        return self.extender.resolve(in: worker)
            .then { _ -> Void in
                // waitUntil does not allow you to return a value
                ()
            }
    }
}
