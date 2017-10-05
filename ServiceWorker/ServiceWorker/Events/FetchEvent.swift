import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol FetchEventExports: Event, JSExport {
    func respondWith(_: JSValue)
    var request: FetchRequest { get }
}

@objc public class FetchEvent: NSObject, FetchEventExports {

    let request: FetchRequest
    var respondValue: JSValue?
    public let type = "fetch"

    func respondWith(_ val: JSValue) {
        if self.respondValue != nil {
            let err = JSValue(newErrorFromMessage: "respondWith() has already been called", in: val.context)
            val.context.exception = err
            return
        }
        self.respondValue = val
    }

    public init(request: FetchRequest) {
        self.request = request
        super.init()
    }

    public func resolve(in _: ServiceWorker) throws -> Promise<JSManagedValue?> {
        guard let promise = self.respondValue else {
            return Promise(value: nil)
        }

        guard let resolve = promise.context
            .evaluateScript("(val) => Promise.resolve(val)")
            .call(withArguments: [promise]) else {
            throw ErrorMessage("Could not call Promise.resolve() on provided value")
        }

        return JSPromise.fromJSValue(resolve)
    }
}
