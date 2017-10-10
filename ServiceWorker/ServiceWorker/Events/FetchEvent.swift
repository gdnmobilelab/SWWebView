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

        guard let resolved = val.context
            .evaluateScript("(val) => Promise.resolve(val)")
            .call(withArguments: [val]) else {
            let err = JSValue(newErrorFromMessage: "Could not call Promise.resolve() on provided value", in: val.context)
            val.context.exception = err
            return
        }

        self.respondValue = resolved
    }

    public init(request: FetchRequest) {
        self.request = request
        super.init()
    }

    public func resolve(in _: ServiceWorker) throws -> Promise<FetchResponseProtocol?> {
        guard let promise = self.respondValue else {
            return Promise(value: nil)
        }

        guard let exec = ServiceWorkerExecutionEnvironment.contexts.object(forKey: promise.context) else {
            return Promise(error: ErrorMessage("Could not get execution environment for this JSContext"))
        }

        return JSContextPromise(jsValue: promise, thread: exec.thread).resolve()
    }
}
