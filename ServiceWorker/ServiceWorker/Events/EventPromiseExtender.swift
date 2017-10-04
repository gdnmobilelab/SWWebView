import Foundation
import JavaScriptCore
import PromiseKit

class EventPromiseExtender {

    public enum ExtendableEventState {
        case valid
        case invalid
        case resolved
    }

    var state: ExtendableEventState = .valid

    fileprivate var pendingPromises: [JSManagedValue] = []

    func add(_ val: JSValue) {

        if self.state == .invalid {
            val.context.exception = JSValue(newErrorFromMessage: "Invalid state for waitUntil()", in: val.context)
            return
        }
        guard let managed = JSManagedValue(value: val, andOwner: self) else {
            let err = JSValue(newErrorFromMessage: "Could not create JSManagedValue for waitUntil()", in: val.context)
            val.context.exception = err
            return
        }
        val.context.virtualMachine.addManagedReference(managed, withOwner: self)

        self.pendingPromises.append(managed)
    }

    fileprivate func clearManagedReferences() {
        self.pendingPromises.forEach { managed in
            if let context = managed.value?.context {
                context.virtualMachine.removeManagedReference(managed, withOwner: self)
            }
        }
        self.pendingPromises.removeAll()
    }

    deinit {
        self.clearManagedReferences()
    }

    func resolve(in worker: ServiceWorker) -> Promise<JSValue> {

        self.state = .resolved

        return Promise<JSValue> { fulfill, reject in

            let success: @convention(block) (JSValue) -> Void = { val in
                fulfill(val)
            }

            let failure: @convention(block) (JSValue) -> Void = { val in

                let err = ErrorMessage(val.objectForKeyedSubscript("message").toString())
                reject(err)
            }

            worker.withJSContext { context in

                guard let jsFunc = context.evaluateScript("""
                    (function(promises, success, failure) {
                        return Promise.all(promises).then(success).catch(failure)
                    })
                """) else {
                    reject(ErrorMessage("Failed to wrap promise inside JS context"))
                    return
                }

                let successCast = unsafeBitCast(success, to: AnyObject.self)
                let failureCast = unsafeBitCast(failure, to: AnyObject.self)

                jsFunc.call(withArguments: [self.pendingPromises, successCast, failureCast])

                if context.exception != nil {
                    throw ErrorMessage(context.exception.toString())
                }

            }.catch { error in
                reject(error)
            }.always {
                self.clearManagedReferences()
            }
        }
    }
}
