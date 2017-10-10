import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol ExtendableEventExports: Event, JSExport {
    func waitUntil(_: JSValue)
}

@objc public class ExtendableEvent: NSObject, ExtendableEventExports {

    public let type: String

    init(type: String) {
        self.type = type
    }

    public enum ExtendableEventState {
        case valid
        case invalid
        case resolved
    }

    var state: ExtendableEventState = .valid

    fileprivate var pendingPromises: [JSValue] = []

    func waitUntil(_ val: JSValue) {

        if self.state == .invalid {
            val.context.exception = JSValue(newErrorFromMessage: "Invalid state for waitUntil()", in: val.context)
            return
        }
        //        guard let managed = JSManagedValue(value: val, andOwner: self) else {
        //            let err = JSValue(newErrorFromMessage: "Could not create JSManagedValue for waitUntil()", in: val.context)
        //            val.context.exception = err
        //            return
        //        }
        //        val.context.virtualMachine.addManagedReference(managed, withOwner: self)

        self.pendingPromises.append(val)
    }

    fileprivate func clearManagedReferences() {
        //        self.pendingPromises.forEach { managed in
        //            if let context = managed.value?.context {
        //                context.virtualMachine.removeManagedReference(managed, withOwner: self)
        //            }
        //        }
        self.pendingPromises.removeAll()
    }

    deinit {
        self.clearManagedReferences()
    }

    //    func resolve(in worker: ServiceWorker) -> Promise<Void> {
    //
    //        return self.resolve(in: worker)
    //            .then { (_: JSValueConvert.VoidReturn) -> Void in
    //                ()
    //            }
    //    }

    func resolve<T>(in worker: ServiceWorker) -> Promise<T> {

        self.state = .resolved

        return Promise<T> { fulfill, reject in

            worker.withJSContext { context in

                let success: @convention(block) (JSValue) -> Void = { val in
                    do {

                        if T.self == JSContextPromise.self {
                            guard let promise = JSContextPromise(jsValue: val, thread: Thread.current) as? T else {
                                throw ErrorMessage("Cannot convert JSContextPromise to JSContextPromise, which should always be possible?")
                            }
                            fulfill(promise)
                        }

                        let transformed: T = try JSConvert.from(any: val.toObject())
                        fulfill(transformed)
                    } catch {
                        reject(error)
                    }
                }

                let failure: @convention(block) (JSValue) -> Void = { val in

                    let err = ErrorMessage(val.objectForKeyedSubscript("message").toString())
                    reject(err)
                }

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
