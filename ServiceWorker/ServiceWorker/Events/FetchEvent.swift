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

        guard let dispatchQueue = ServiceWorkerExecutionEnvironment.contextDispatchQueues.object(forKey: val.context) else {
            Log.error?("Could not get dispatch queue for this JSContext")
            return
        }

        dispatchPrecondition(condition: DispatchPredicate.onQueue(dispatchQueue))

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

    public func resolve(in worker: ServiceWorker) throws -> Promise<FetchResponseProtocol?> {
        guard let promise = self.respondValue else {
            return Promise(value: nil)
        }

        guard let dispatchQueue = worker.dispatchQueue else {
            return Promise(error: ErrorMessage("Could not get dispatch queue for worker"))
        }

        guard let resolve = promise.context
            .evaluateScript("(val) => Promise.resolve(val)")
            .call(withArguments: [promise]) else {
            throw ErrorMessage("Could not call Promise.resolve() on provided value")
        }

        return JSContextPromise(jsValue: resolve, dispatchQueue: dispatchQueue).resolve()
    }
}
