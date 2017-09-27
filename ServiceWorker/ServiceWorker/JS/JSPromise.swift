import Foundation
import JavaScriptCore
import PromiseKit

public class JSPromise {

    unowned let context: JSContext
    let virtualMachine: JSVirtualMachine
    fileprivate var fulfill: JSValue?
    fileprivate var reject: JSValue?
    fileprivate var promiseJSValue: JSValue?

    fileprivate let thereWasNoPromiseConstructor: Bool

    public init(context: JSContext) {
        self.context = context
        self.virtualMachine = context.virtualMachine

        guard let promiseConstructor = self.context.objectForKeyedSubscript("Promise") else {
            context.exception = JSValue(newErrorFromMessage: "Tried to create a Promise, but this context has no Promise constructor", in: context)
            self.thereWasNoPromiseConstructor = true
            return
        }

        self.thereWasNoPromiseConstructor = false

        let capture: @convention(block) (JSValue, JSValue) -> Void = { [unowned self] (fulfillVal: JSValue, rejectVal: JSValue) in

            //            let fulfillManaged = JSManagedValue(value: fulfillVal)
            //            let rejectManaged = JSManagedValue(value: rejectVal)
            //
            //            self.virtualMachine.addManagedReference(fulfillManaged, withOwner: self)
            //            self.virtualMachine.addManagedReference(rejectManaged, withOwner: self)

            self.fulfill = fulfillVal
            self.reject = rejectVal
        }

        let val = promiseConstructor.construct(withArguments: [unsafeBitCast(capture, to: AnyObject.self)])
        promiseJSValue = val // JSManagedValue(value: val)
        //        virtualMachine.addManagedReference(self.promiseJSValue, withOwner: self)
    }

    public var jsValue: JSValue? {
        return self.promiseJSValue
    }

    deinit {
        self.fulfill = nil
        self.reject = nil
        self.promiseJSValue = nil
    }

    public func fulfill(_ value: Any?) {

        if let fulfill = self.fulfill {
            if let val = value {

                fulfill.call(withArguments: [val])
            } else {
                fulfill.call(withArguments: [NSNull()])
            }
        } else if self.thereWasNoPromiseConstructor == true {
            Log.warn?("Tried to resolve a promise in a JS context that has no promise constructor")
        } else {
            Log.error?("Tried to resolve a JS promise but the reference to fulfill has been lost")
        }
    }

    public func reject(_ error: Error) {

        if let reject = self.reject {
            guard let err = JSValue(newErrorFromMessage: "\(error)", in: context) else {
                Log.error?("Could not create JS instance of promise rejection error")
                return
            }
            reject.call(withArguments: [err])
        } else if self.thereWasNoPromiseConstructor == true {
            Log.warn?("Tried to reject a promise in a JS context that has no promise constructor")
        } else {
            Log.error?("Tried to reject a JS promise but the reference to reject has been lost")
        }
    }

    public func processCallback(_ error: Error?, _ returnObject: Any?) {
        if let err = error {
            self.reject(err)
        } else if let ret = returnObject {
            self.fulfill(ret)
        } else {
            self.reject(ErrorMessage("A callback returned neither an error nor a response"))
        }
    }

    public func processCallback<I, O>(transformer: @escaping (I) -> O) -> (Error?, I?) -> Void {
        return { error, result in
            if let errorExists = error {
                self.reject(errorExists)
            } else if let resultExists = result {
                self.fulfill(transformer(resultExists))
            } else {
                self.reject(ErrorMessage("Callback returned no error and also no result"))
            }
        }
    }

    public func processCallback(_ error: Error?) {
        if let err = error {
            self.reject(err)
        } else {
            self.fulfill(nil)
        }
    }

    public static func fromJSValue(_ promise: JSValue) -> Promise<JSManagedValue?> {

        return Promise { fulfill, reject in

            let reject: @convention(block) (JSValue) -> Void = { err in
                reject(ErrorMessage(err.objectForKeyedSubscript("message").toString()))
            }
            let fulfill: @convention(block) (JSValue?) -> Void = { result in
                fulfill(JSManagedValue(value: result))
            }

            guard let bindFunc = promise.context.evaluateScript("(function(promise,thenFunc,catchFunc) { return promise.then(thenFunc).catch(catchFunc)})") else {
                throw ErrorMessage("Could not wrap JS promise into PromiseKit promise")
            }

            bindFunc.call(withArguments: [promise, unsafeBitCast(fulfill, to: AnyObject.self), unsafeBitCast(reject, to: AnyObject.self)])
        }
    }

    public static func resolve(_ promise: JSValue, _ cb: @escaping (Error?, JSValue?) -> Void) {

        let reject: @convention(block) (JSValue) -> Void = { err in
            cb(ErrorMessage(err.objectForKeyedSubscript("message").toString()), nil)
        }
        let fulfill: @convention(block) (JSValue?) -> Void = { result in
            cb(nil, result)
        }

        guard let bindFunc = promise.context.evaluateScript("(function(promise,thenFunc,catchFunc) { return promise.then(thenFunc).catch(catchFunc)})") else {
            cb(ErrorMessage("Could not wrap promise in JS"), nil)
            return
        }

        bindFunc.call(withArguments: [promise, unsafeBitCast(fulfill, to: AnyObject.self), unsafeBitCast(reject, to: AnyObject.self)])
    }
}
