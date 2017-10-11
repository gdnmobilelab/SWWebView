import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol ExtendableEventExports: Event, JSExport {
    func waitUntil(_: JSValue)
}

/// A version of the ExtendableEvent interface service workers use: https://developer.mozilla.org/en-US/docs/Web/API/ExtendableEvent
/// it lets us prolong the life of an event by sending a promise to waitUntil(). It's useful in the install and active events
/// to not update the state of a worker until you've cached URLs, set up a database, etc.
@objc public class ExtendableEvent: NSObject, ExtendableEventExports {

    public let type: String

    public init(type: String) {
        self.type = type
    }

    fileprivate enum ExtendableEventState {
        case valid
        case resolved
    }

    /// You can only call waitUntil() when the event is initally dispatched - after that point resolve() has
    /// been called and the promise can't be added to the chain.
    fileprivate var state: ExtendableEventState = .valid

    /// You can call waitUntil() multiple times, chaining multiple promises one after the other. This array
    /// keeps track of those promises.
    fileprivate var pendingPromises: [JSValue] = []

    func waitUntil(_ val: JSValue) {

        if self.state == .resolved {
            val.context.exception = JSValue(newErrorFromMessage: "You used waitUntil() too late - the event has already been resolved", in: val.context)
            return
        }

        self.pendingPromises.append(val)
    }

    fileprivate func clearManagedReferences() {
        self.pendingPromises.removeAll()
    }

    deinit {
        self.clearManagedReferences()
    }

    public func resolve(in worker: ServiceWorker) -> Promise<Void> {

        self.state = .resolved

        // Create a native promise to bridge the JS promise success/failure

        let (promise, fulfill, reject) = Promise<Void>.pending()

        // We run this inside a withJSContext() call because we create a JSValue then
        // execute it - withJSContext runs on the worker thread, so we know we won't be leaking
        // any JSValues anywhere.

        return worker.withJSContext { context in

            let success: @convention(block) (JSValue) -> Void = { _ in

                // If our promise(es) resolve successfully, we can safely resolve our
                // native promise. ExtendableEvents can't actually return a value
                // (unlike, say, FetchEvent) so we don't need to worry about
                // what the return value actually is.

                fulfill(())
            }

            let failure: @convention(block) (JSValue) -> Void = { val in

                // If our promise chain fails, we grab the message and turn it into a native
                // error. We can probably improve on this and add more useful error information.

                let err = ErrorMessage(val.objectForKeyedSubscript("message").toString())
                reject(err)
            }

            // If we don't cast to AnyObject the functions don't seem to work in a JSContext.

            let successCast = unsafeBitCast(success, to: AnyObject.self)
            let failureCast = unsafeBitCast(failure, to: AnyObject.self)

            // Now create a JS function that calls Promise.resolve() on all the values passed into
            // waitUntil() (in case they aren't promises, though they really should be), then waits
            // until all are executed, then grafts our success and failure functions onto the end

            guard let jsFunc = context.evaluateScript("""
                (function(promises, success, failure) {
                    let resolved = promises.map(p => Promise.resolve(p));
                    return Promise.all(resolved).then(success).catch(failure)
                })
            """) else {
                throw ErrorMessage("Failed to wrap promise inside JS context")
            }

            // Now call the function we just made to actually resolve the promise.

            jsFunc.call(withArguments: [self.pendingPromises, successCast, failureCast])

            // Because we're not doing this with the usual evaluateScript() call, we need
            // to manually throw any error that occurred.

            if context.exception != nil {
                throw ErrorMessage(context.exception.toString())
            }
        }
        .then {

            // Now that the withJSContext() code has executed, we return the original
            // promise we created, which will resolve once the jsFunc call above resolves
            // all the JS promises.

            promise

        }.always {

            // There's no point keeping onto the JSValues that were attached with waitUntil()
            // once the promise has been resolved or rejected, so we'll proactively clear them out.

            self.clearManagedReferences()
        }
    }
}
