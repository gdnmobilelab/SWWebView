import Foundation
import PromiseKit
import JavaScriptCore

/// One of the more important classes in the project, this wraps JavaScript promises
/// (which, thankfully, are native in JSContext) and lets us fulfill and reject them
/// from native code.
@objc public class JSContextPromise: NSObject {

    // We can fulfill and reject promises we create ourselves, but not existing promises.
    // So we keep track which type this is, in order to write more meaningful error messages.
    fileprivate enum PromiseCreationMethod {
        case natively
        case fromJSValue
    }

    fileprivate let creationMethod: PromiseCreationMethod

    // Promises can only be resolved once, so let's keep track of that too.
    fileprivate var resolved = false

    /// This is a reference to the actual promise itself
    var jsValue: JSValue?

    /// This is the JavaScript function we call to fulfill the promise
    fileprivate var fulfillJSValue: JSValue?

    /// And this is the function we call to reject the promise
    fileprivate var rejectJSValue: JSValue?

    /// We keep a reference to this to make sure that we run our promise resolution
    /// on the worker thread no matter where it's called.
    fileprivate let thread: Thread

    /// This initialiser is for an existing promise in the JSContext that we want
    /// to wrap. We can only resolve() these promises, not fulfill() or reject() them.
    ///
    /// - Parameters:
    ///   - jsValue: The promise variable
    ///   - thread: The worker thread this variable was created in
    public required init(jsValue: JSValue, thread: Thread) {
        self.creationMethod = .fromJSValue
        self.jsValue = jsValue
        self.thread = thread
    }

    /// This is a kind of silly utility class we're using to allow us to run functions
    /// on the worker thread - perform() only accepts one argument, so we combine
    /// context and error together.
    @objc fileprivate class ContextInit: NSObject {
        let context: JSContext
        var error: Error?

        init(ctx: JSContext) {
            self.context = ctx
            super.init()
        }
    }

    /// This initialiser is for creating a new promise, which we are able to run
    /// fulfill(), reject() and resolve() on.
    ///
    /// - Parameter context: The JSContext to create the promise in
    /// - Throws: If there is no worker thread (i.e. this class is used on a non-service worker JSContext)
    public init(newPromiseInContext context: JSContext) throws {

        self.creationMethod = .natively

        guard let exec = ServiceWorkerExecutionEnvironment.contexts.object(forKey: context) else {
            throw ErrorMessage("Cannot find thread for this context")
        }
        self.thread = exec.thread

        super.init()

        // We want to ensure we create the promise on the worker thread (just in case) so we run getContextValues()
        // through NSObject.perform():

        let ctxInit = ContextInit(ctx: context)
        self.perform(#selector(JSContextPromise.getContextValues(from:)), on: self.thread, with: ctxInit, waitUntilDone: true)

        if let error = ctxInit.error {
            throw error
        }
    }

    /// Ensure that we are on the worker thread before performing any other actions
    fileprivate func checkThread() {
        if Thread.current != self.thread {
            fatalError("JSContextPromise being run on incorrect thread")
        }
    }

    /// Populate our class with the fulfill and reject functions we need to call from Swift. In a separate
    /// function so that we can ensure we call this on the worker thread.
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

    /// Does exactly what you'd expect - fulfills the JavaScript promise.
    public func fulfill(_ val: Any) {

        if self.resolved == true {
            Log.error?("Tried to resolve a promise that has already been resolved")
            return
        }

        self.resolved = true

        if let fulfill = self.fulfillJSValue {

            // Actually run the JS function:
            fulfill.perform(#selector(JSValue.call(withArguments:)), on: self.thread, with: [val], waitUntilDone: false)

            // We clear out the JSValues at this point because you can only resolve a promise once,
            // so we might as well free them up for garbage collection.

            self.rejectJSValue = nil
            self.fulfillJSValue = nil

        } else {

            if self.creationMethod == .fromJSValue {
                Log.error?("Tried to fulfill a promise captured from JSContext. We can only resolve promises we create natively")
            } else {
                Log.error?("Tried to fulfill promise but function doesn't exist. This should never happen")
            }
            // If this is a promise we haven't created ourselves, we can't resolve it. Future improvement
            // might be to indicate that

            Log.error?("Could not fulfill this JSPromise")
        }
    }

    public func reject(_ error: Error) {

        if self.resolved == true {
            Log.error?("Tried to resolve a promise that has already been resolved")
            return
        }

        self.resolved = true

        do {
            guard let reject = self.rejectJSValue else {
                if self.creationMethod == .fromJSValue {
                    throw ErrorMessage("Tried to reject a promise captured from JSContext. We can only resolve promises we create natively")
                } else {
                    throw ErrorMessage("Tried to reject promise but function doesn't exist. This should never happen")
                }
            }

            // Transform our native error into a JS one:
            guard let errJS = JSValue(newErrorFromMessage: "\(error)", in: reject.context) else {
                throw ErrorMessage("Could not create JavaScript error")
            }

            // Then reject the promise in JS:
            reject.perform(#selector(JSValue.call(withArguments:)), on: self.thread, with: [errJS], waitUntilDone: false)

            self.rejectJSValue = nil
            self.fulfillJSValue = nil

        } catch {
            Log.error?("\(error)")
        }
    }

    /// This is called by resolve(), it's in its own function to ensure that we are
    /// running on the worker thread. It will attempt to resolve a JS promise and
    /// send the result to our native environment.
    @objc fileprivate func resolveOnThread(_ returnVal: PromisePassthrough) {

        self.checkThread()

        // the fulfill function we'll make JS compatible and pass into the context:

        let fulfillConvention: @convention(block) (JSValue) -> Void = { returnValue in
            returnVal.fulfill(returnValue.toObject())
        }

        // and the equivalent reject function:

        let rejectConvention: @convention(block) (JSValue) -> Void = { returnValue in

            let err = returnValue.objectForKeyedSubscript("message").toString()

            returnVal.reject(ErrorMessage(err ?? "JS promise failed, could not extract error message"))
        }

        guard let jsValue = self.jsValue else {
            returnVal.reject(ErrorMessage("Tried to resolve a JS promise but the reference no longer exists. This should never happen."))
            return
        }

        // Now we make a JS function and immediately call it (performance implications??) to attach our native
        // resolve and reject functions to the JS promise chain.

        jsValue.context.evaluateScript("""
            (promise,fulfill,reject) => {
                promise.then(fulfill).catch(reject)
            }
        """).call(withArguments: [jsValue, unsafeBitCast(fulfillConvention, to: AnyObject.self), unsafeBitCast(rejectConvention, to: AnyObject.self)])
    }

    /// The wrapper around resolveOnThread() that can be called from anywhere. Is also a Swift generic, so
    /// the Promise passthrough will convert the resolved value to whatever we want (if it can)
    public func resolve<T>() -> Promise<T> {

        let (promise, passthrough) = Promise<T>.makePassthrough()

        self.perform(#selector(JSContextPromise.resolveOnThread(_:)), on: self.thread, with: passthrough, waitUntilDone: false)

        return promise
    }
}
