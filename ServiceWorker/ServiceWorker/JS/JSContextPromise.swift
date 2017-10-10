import Foundation
import PromiseKit
import JavaScriptCore

@objc public class JSContextPromise: NSObject {

    var jsValue: JSValue?
    fileprivate var fulfillJSValue: JSValue?
    fileprivate var rejectJSValue: JSValue?
    fileprivate let thread: Thread

    public required init(jsValue: JSValue, thread: Thread) {
        self.jsValue = jsValue
        self.thread = thread
    }

    public init(newPromiseInContext context: JSContext) throws {
        guard let exec = ServiceWorkerExecutionEnvironment.contexts.object(forKey: context) else {
            throw ErrorMessage("Cannot find thread for this context")
        }
        self.thread = exec.thread
        let ctxInit = ContextInit(ctx: context)
        super.init()
        self.getContextValues(from: ctxInit)

        if let error = ctxInit.error {
            throw error
        }
    }

    fileprivate func checkThread() {
        if Thread.current != self.thread {
            fatalError("JSContextPromise being run on incorrect thread")
        }
    }

    @objc fileprivate init(in thread: Thread) {
        self.thread = thread
    }

    @objc fileprivate class ContextInit: NSObject {
        let context: JSContext
        var error: Error?

        init(ctx: JSContext) {
            self.context = ctx
            super.init()
        }
    }

    @objc fileprivate func getContextValues(from contextInit: ContextInit) {
        do {
            guard let promiseConstructor = contextInit.context.objectForKeyedSubscript("Promise") else {
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
        } catch {
            contextInit.error = error
        }
    }

    public static func makeInCurrentContext() -> JSContextPromise {

        guard let ctx = JSContext.current() else {
            fatalError("Tried to create a JSPromise outside of a JSContext")
        }

        do {

            guard let exec = ServiceWorkerExecutionEnvironment.contexts.object(forKey: ctx) else {
                throw ErrorMessage("Could not find thread associated with this JSContext")
            }

            let promise = JSContextPromise(in: exec.thread)

            let ctxInit = ContextInit(ctx: ctx)

            promise.perform(#selector(JSContextPromise.getContextValues(from:)), on: exec.thread, with: ctxInit, waitUntilDone: true)

            if let error = ctxInit.error {
                throw error
            }

            return promise

        } catch {
            let err = JSValue(newErrorFromMessage: "\(error)", in: ctx)
            ctx.exception = err
            fatalError("\(error)")
        }
    }

    public func fulfill(_ val: Any) {

        if let fulfill = self.fulfillJSValue {
            fulfill.perform(#selector(JSValue.call(withArguments:)), on: self.thread, with: [val], waitUntilDone: false)
            self.rejectJSValue = nil
            self.fulfillJSValue = nil
        } else {
            Log.error?("Could not fulfill this JSPromise")
        }
    }

    public func reject(_ error: Error) {
        do {
            guard let reject = self.rejectJSValue else {
                throw ErrorMessage("Cannot reject this promise")
            }

            guard let errJS = JSValue(newErrorFromMessage: "\(error)", in: reject.context) else {
                throw ErrorMessage("Could not create JavaScript error")
            }

            reject.perform(#selector(JSValue.call(withArguments:)), on: self.thread, with: [errJS], waitUntilDone: false)

        } catch {
            Log.error?("\(error)")
        }
    }

    //    public func resolve() -> Promise<Void> {
    //        return self.resolve()
    //            .then { (_: Any) in
    //                ()
    //            }
    //    }

    @objc fileprivate func resolveOnThread(_ returnVal: ServiceWorkerExecutionEnvironment.PromiseWrappedCall) {

        self.checkThread()

        let fulfillConvention: @convention(block) (JSValue) -> Void = { returnValue in
            returnVal.fulfill(returnValue.toObject())
        }

        let rejectConvention: @convention(block) (JSValue) -> Void = { returnValue in

            let err = returnValue.objectForKeyedSubscript("message").toString()

            returnVal.reject(ErrorMessage(err ?? "Could not extract error message"))
        }

        guard let jsValue = self.jsValue else {
            returnVal.reject(ErrorMessage("Promise JSValue was lost"))
            return
        }

        jsValue.context.evaluateScript("""
            (promise,fulfill,reject) => {
                debugger;
                return promise.then(fulfill).catch(reject)
            }
        """).call(withArguments: [jsValue, unsafeBitCast(fulfillConvention, to: AnyObject.self), unsafeBitCast(rejectConvention, to: AnyObject.self)])
    }

    public func resolve<T>() -> Promise<T> {

        let wrapped = ServiceWorkerExecutionEnvironment.PromiseWrappedCall()

        self.perform(#selector(JSContextPromise.resolveOnThread(_:)), on: self.thread, with: wrapped, waitUntilDone: false)

        return wrapped.promise
            .then { anyResult -> T in
                try JSConvert.from(any: anyResult)
            }
    }
}
