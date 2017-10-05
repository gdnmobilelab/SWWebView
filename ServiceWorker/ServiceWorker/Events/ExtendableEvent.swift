import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol ExtendableEventExports: Event, JSExport {
    func waitUntil(_: JSValue)
}

@objc public class ExtendableEvent: NSObject, ExtendableEventExports {

    let extender = EventPromiseExtender()
    public let type: String

    func waitUntil(_ val: JSValue) {

        self.extender.add(val)
    }

    init(type: String) {
        self.type = type
    }

    public func resolve(in worker: ServiceWorker) -> Promise<Void> {

        return self.extender.resolve(in: worker)
            .then { _ -> Void in
                // waitUntil does not allow you to return a value
                ()
            }
    }
}
