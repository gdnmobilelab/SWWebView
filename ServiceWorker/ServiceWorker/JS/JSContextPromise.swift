import Foundation
import PromiseKit
import JavaScriptCore

public class JSContextPromise {

    var jsValue: JSValue?
    fileprivate var fulfillJSValue: JSValue?
    fileprivate var rejectJSValue: JSValue?
    let dispatchQueue: DispatchQueue

    public required init(jsValue: JSValue, dispatchQueue: DispatchQueue) {
        self.jsValue = jsValue
        self.dispatchQueue = dispatchQueue
    }

    public init(newPromiseInContext context: JSContext, dispatchQueue: DispatchQueue) throws {
        self.dispatchQueue = dispatchQueue

        dispatchPrecondition(condition: DispatchPredicate.onQueue(self.dispatchQueue))

        //        try self.dispatchQueue.sync {
        guard let promiseConstructor = context.objectForKeyedSubscript("Promise") else {
            throw ErrorMessage("Promise constructor does not exist in JSContext")
        }

        let receiver: @convention(block) (JSValue?, JSValue?) -> Void = { [unowned self] fulfill, reject in
            self.fulfillJSValue = fulfill
            self.rejectJSValue = reject
        }

        guard let jsValue = promiseConstructor.construct(withArguments: [unsafeBitCast(receiver, to: AnyObject.self)]) else {
            throw ErrorMessage("Promise constructor did not return a promise")
        }

        if self.fulfillJSValue == nil || self.rejectJSValue == nil {
            throw ErrorMessage("Promise constructor did not return resolution functions")
        }

        self.jsValue = jsValue
        //        }
    }

    public static func makeInCurrentContext() -> JSContextPromise {

        guard let ctx = JSContext.current() else {
            fatalError("Tried to create a JSPromise outside of a JSContext")
        }

        do {

            guard let dispatchQueue = ServiceWorkerExecutionEnvironment.contextDispatchQueues.object(forKey: ctx) else {
                throw ErrorMessage("Could not get dispatch queue for current context")
            }

            return try JSContextPromise(newPromiseInContext: ctx, dispatchQueue: dispatchQueue)

        } catch {
            let err = JSValue(newErrorFromMessage: "\(error)", in: ctx)
            ctx.exception = err
            fatalError("\(error)")
        }
    }

    //    public static func tryFulfill(_ callback: (JSContextPromise) throws -> Void) -> JSValue? {
    //
    //        guard let ctx = JSContext.current() else {
    //            fatalError("Tried to create JSPromise with no active JSContext")
    //        }
    //
    //        do {
    //
    //            guard let dispatchQueue = ServiceWorkerExecutionEnvironment.contextDispatchQueues.object(forKey: ctx) else {
    //                throw ErrorMessage("Could not get dispatch queue for current context")
    //            }
    //
    //            let promise = try JSContextPromise(newPromiseInContext: ctx, dispatchQueue: dispatchQueue)
    //
    //            try callback
    //
    //        } catch {
    //            let err = JSValue(newErrorFromMessage: "\(error)", in: ctx)
    //            ctx.exception = err
    //            return nil
    //        }
    //
    //    }

    public func fulfill(_ val: Any) {

        self.dispatchQueue.async {
            if let fulfill = self.fulfillJSValue {
                fulfill.call(withArguments: [val])
                self.rejectJSValue = nil
                self.fulfillJSValue = nil
            } else {
                Log.error?("Could not fulfill this JSPromise")
            }
        }
    }

    public func reject(_ error: Error) {
        self.dispatchQueue.async {
            do {
                guard let reject = self.rejectJSValue else {
                    throw ErrorMessage("Cannot reject this promise")
                }

                guard let errJS = JSValue(newErrorFromMessage: "\(error)", in: reject.context) else {
                    throw ErrorMessage("Could not create JavaScript error")
                }

                reject.call(withArguments: [errJS])
            } catch {
                Log.error?("\(error)")
            }
        }
    }

    public func resolve() -> Promise<Void> {
        return self.resolve()
            .then(on: self.dispatchQueue, execute: { (_: JSValue) in
                ()
            })
    }

    public func resolve<T>() -> Promise<T> {

        return Promise { fulfill, reject in

            dispatchQueue.async {
                let fulfillConvention: @convention(block) (JSValue) -> Void = { returnValue in

                    dispatchPrecondition(condition: .onQueue(self.dispatchQueue))
                    NSLog("Resolve promise value \(returnValue) to \(T.self)")
                    if T.self == JSValue.self, let jsValue = returnValue as? T {
                        fulfill(jsValue)
                    } else if let convertedValue = returnValue.toObject() as? T {
                        fulfill(convertedValue)
                    } else {
                        reject(ErrorMessage("Could not resolve promise to required type"))
                    }
                }

                let rejectConvention: @convention(block) (JSValue) -> Void = { returnValue in

                    dispatchPrecondition(condition: .onQueue(self.dispatchQueue))

                    let err = returnValue.objectForKeyedSubscript("message").toString()

                    reject(ErrorMessage(err ?? "Could not extract error message"))
                }

                guard let jsValue = self.jsValue else {
                    reject(ErrorMessage("Promise JSValue was lost"))
                    return
                }

                jsValue.context.evaluateScript("""
                    (promise,fulfill,reject) =>
                        promise.then(fulfill).catch(reject)
                """).call(withArguments: [jsValue, unsafeBitCast(fulfillConvention, to: AnyObject.self), unsafeBitCast(rejectConvention, to: AnyObject.self)])
            }
        }
    }
}
