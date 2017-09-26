import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol ExtendableEventExports: JSExport {
    func waitUntil(_: JSValue)
}

@objc public class ExtendableEvent: Event, ExtendableEventExports {

    public enum ExtendableEventState {
        case valid
        case invalid
        case resolved
    }

    var state: ExtendableEventState = .valid

    fileprivate var pendingPromises: [JSManagedValue] = []

    func waitUntil(_ val: JSValue) {

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
            managed.value.context.virtualMachine.removeManagedReference(managed, withOwner: self)
        }
        self.pendingPromises.removeAll()
    }

    deinit {
        self.clearManagedReferences()
    }

    public func resolve(in worker: ServiceWorker) -> Promise<Void> {

        self.state = .resolved

        return Promise<Void> { fulfill, reject in

            let success: @convention(block) () -> Void = {
                fulfill(())
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
