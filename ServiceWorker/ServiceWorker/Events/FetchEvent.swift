import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol FetchEventExports: JSExport {
    func respondWith(_: JSValue)
    var request: FetchRequest { get }
}

@objc public class FetchEvent: Event, FetchEventExports {

    let request: FetchRequest
    var respondValue: JSValue?

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
        super.init(type: "fetch")
    }

    public required init(type _: String) {
        fatalError("Must create fetch event with request:")
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
