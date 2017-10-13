import Foundation
import JavaScriptCore
import PromiseKit

/// The core class of the project. ServiceWorker itself is actually very lightweight,
/// because we create instances in response to getRegistration() calls and the like - it's
/// only when we run evaluateScript() or dispatchEvent() that the ServiceWorkerExecutionEnvironment
/// (and consequently, JSContext) are created.
@objc public class ServiceWorker: NSObject {

    /// The URL the worker was downloaded from. Also serves as the base URL for any
    /// relative URLs loaded within the worker.
    public let url: URL

    /// In theory you could have multiple instances of the same worker in different registrations
    /// so the URL is not unique enough. Instead we have a unique ID, which is often just a UUID.
    public let id: String

    /// I think we need to rename this to storageDelegate, because that's actually what this has
    /// ended up being.
    public weak var delegate: ServiceWorkerDelegate?

    /// A separate delegate for client webview management
    public weak var clientsDelegate: ServiceWorkerClientsDelegate?
    public var cacheStorage: CacheStorage?

    /// ServiceWorkerRegistration itself will be defined in a different module.
    public var registration: ServiceWorkerRegistrationProtocol?

    /// The install state of the worker is set externally - the worker itself doesn't control it.
    fileprivate var _installState: ServiceWorkerInstallState
    public var state: ServiceWorkerInstallState {
        get {
            return self._installState
        }
        set(value) {
            if self._installState != value {
                self._installState = value

                #if DEBUG
                    // The debugging name is what appears in Safari. It includes the state in the title,
                    // so when we change that title we should also update the debugging name

                    self.setJSContextDebuggingName()
                #endif

                // We also need to pass on this state change to webviews (and other targets?)
                GlobalEventLog.notifyChange(self)
            }
        }
    }

    #if DEBUG
        fileprivate func setJSContextDebuggingName() {
            if let exec = self._executionEnvironment {
                exec.jsContextName = "\(url.absoluteString) (\(state.rawValue))"
            }
        }
    #endif

    public init(id: String, url: URL, state: ServiceWorkerInstallState) {
        self.id = id
        self.url = url
        _installState = state
        super.init()
    }

    /// This needs to be fleshed out more, but sometimes we want to make sure a worker
    /// has completed operations before we shut it down. Right now it only uses WebSQL
    /// stuff, but should probably also include setTimeout.
    public func ensureFinished() -> Promise<Void> {

        if let exec = self._executionEnvironment {
            let (promise, passthrough) = Promise<Void>.makePassthrough()
            exec.perform(#selector(ServiceWorkerExecutionEnvironment.ensureFinished(responsePromise:)), on: exec.thread, with: passthrough, waitUntilDone: false)
            return promise
        }
        return Promise(value: ())
    }

    /// An initialiser to specifically call in Objective-C - the InstallState enum
    /// is string-based, which Objective-C doesn't support, so instead we'll just
    /// take a string and throw if it doesn't match a value.
    @objc public convenience init(id: String, url: URL, state: String) throws {
        guard let installState = ServiceWorkerInstallState(rawValue: state) else {
            throw ErrorMessage("Could not parse install state string")
        }

        self.init(id: id, url: url, state: installState)
    }

    /// We lazy load the execution environment if and when it is needed. Once loaded, we store
    /// it in this variable so we don't have to spin it up for every event we dispatch. To be resolved:
    /// how we decide when to spin it back down again (I think Chrome uses a timeout?)
    fileprivate var _executionEnvironment: ServiceWorkerExecutionEnvironment?

    /// The process of creating the execution environment is asynchronous, so if you ran getExecutionEnvironment()
    /// while getExecutionEnvironment() is executing, you'd end up with two copies of the same environment.
    /// To avoid this, we save the async promise here and, if it exists, return it when getExecutionEnvironment()
    /// is run for the second time.
    fileprivate var loadingExecutionEnvironmentPromise: Promise<ServiceWorkerExecutionEnvironment>?

    internal func getExecutionEnvironment() -> Promise<ServiceWorkerExecutionEnvironment> {

        if let exec = _executionEnvironment {
            return Promise(value: exec)
        }

        if let loadingPromise = self.loadingExecutionEnvironmentPromise {

            // Our worker script loads asynchronously, so it's possible that
            // getExecutionEnvironment() could be run while an existing environment
            // is being created. Adding this promise means we can close that loop
            // and ensure we only ever have one environment per worker.

            return loadingPromise
        }

        // Being lazy means that we can create instances of ServiceWorker whenever we feel
        // like it (like, say, when ServiceWorkerRegistration is populating active, waiting etc)
        // without incurring a huge penalty for doing so.

        Log.info?("Creating execution environment for worker: " + id)

        return firstly { () -> Promise<ServiceWorkerExecutionEnvironment> in

            let (promise, fulfill, reject) = Promise<ServiceWorkerExecutionEnvironment>.pending()

            // The execution environment saves Thread.currentThread in its initialiser, so we don't
            // need to assign the variable here. We create the environment on-thread to try to keep
            // absolutely all JavaScriptCore stuff inside one thread.

            Thread.detachNewThread { [unowned self] in
                do {

                    let env = try ServiceWorkerExecutionEnvironment(self)

                    // Return the promise early, before we run...
                    fulfill(env)

                    // This function runs an infinite loop, until env.stop() is called, at which
                    // point the run loop is terminated and this function will complete, closing
                    // down the thread.

                    env.run()

                } catch {
                    reject(error)
                }
            }

            return promise
        }
        .then { env in

            // Now that we have a context, we need to load the actual worker script.

            guard let delegate = self.delegate else {
                throw ErrorMessage("This worker has no delegate to load content through")
            }

            let script = try delegate.serviceWorkerGetScriptContent(self)

            // And then evaluate that script on the worker thread, waiting for it to complete.

            let (promise, passthrough) = Promise<Void>.makePassthrough()

            let eval = ServiceWorkerExecutionEnvironment.EvaluateScriptCall(script: script, url: self.url, passthrough: passthrough, returnType: .void)

            env.perform(#selector(ServiceWorkerExecutionEnvironment.evaluateScript(_:)), on: env.thread, with: eval, waitUntilDone: false)

            let finalChain = promise
                .then { (_) -> ServiceWorkerExecutionEnvironment in
                    self._executionEnvironment = env
                    self.setJSContextDebuggingName()
                    return env
                }
                .always {

                    // Now that this promise is done, clear it out. It doesn't really matter because getExecutionEnvironment()
                    // will now just return self._executionEnvironment, but worth tidying up for when we implement spinning
                    // the environment back down again.

                    self.loadingExecutionEnvironmentPromise = nil
                }

            // As mentioned above, this is set to ensure we don't have two environments
            // created for one worker

            self.loadingExecutionEnvironmentPromise = finalChain

            return finalChain
        }
    }

    deinit {
        Log.info?("Service Worker \(self.id) has been deinitialised")
        if let exec = self._executionEnvironment {
            exec.perform(#selector(ServiceWorkerExecutionEnvironment.stop), on: exec.thread, with: nil, waitUntilDone: true)
        }
    }

    /// The actual script execution work happens in ServiceWorkerExecutionEnvironment, but this wraps around that,
    /// making a generic function so we can cast the JS result to whatever native type we want.
    public func evaluateScript<T>(_ script: String) -> Promise<T> {

        return getExecutionEnvironment()
            .then { (exec: ServiceWorkerExecutionEnvironment) -> Promise<T> in

                // We deliberately don't return any kind of JSValue from ServiceWorkerExecutionEnvironment, to avoid
                // any leaking across threads. But JSContextPromise requires a JSValue in order to be created, so
                // we need to pass in an extra argument - if returnType is .promise then the ExecutionEnvironment will
                // create the JSContextPromise on the worker thread then return it. Otherwise it'll just return a
                // generic object.

                let returnType: ServiceWorkerExecutionEnvironment.EvaluateReturnType = T.self == JSContextPromise.self ? .promise : .object

                let (promise, passthrough) = Promise<T>.makePassthrough()

                let call = ServiceWorkerExecutionEnvironment.EvaluateScriptCall(script: script, url: nil, passthrough: passthrough, returnType: returnType)

                exec.perform(#selector(ServiceWorkerExecutionEnvironment.evaluateScript), on: exec.thread, with: call, waitUntilDone: false)

                return promise
            }
    }

    /// We should try to avoid using this wherever possible as it has the potential to leak JSValues, but
    /// sometimes it's necessary to perform some custom code directly onto our JSContext.
    public func withJSContext(_ cb: @escaping (JSContext) throws -> Void) -> Promise<Void> {

        let call = ServiceWorkerExecutionEnvironment.WithJSContextCall(cb)

        return self.getExecutionEnvironment()
            .then { exec in
                exec.perform(#selector(ServiceWorkerExecutionEnvironment.withJSContext), on: exec.thread, with: call, waitUntilDone: false)
                return call.resolveVoid()
            }
    }

    /// Much like evaluateScript, the bulk of the actual work is done in ServiceWorkerExecutionEnviroment - this
    /// is just a wrapper to ensure we end up on the worker thread.
    public func dispatchEvent(_ event: Event) -> Promise<Void> {

        let call = ServiceWorkerExecutionEnvironment.DispatchEventCall(event)

        // Need to actually profile whether this matters for performance, but if the exec environment already
        // exists we just use it directly, rather than call the promise. The promise should return immediately
        // anyway but there might be a small overhead?

        if let exec = self._executionEnvironment {

            exec.perform(#selector(ServiceWorkerExecutionEnvironment.dispatchEvent), on: exec.thread, with: call, waitUntilDone: false)

            return call.resolveVoid()

        } else {

            return self.getExecutionEnvironment()
                .then { exec in
                    exec.perform(#selector(ServiceWorkerExecutionEnvironment.dispatchEvent), on: exec.thread, with: call, waitUntilDone: false)
                    return call.resolveVoid()
                }
        }
    }

    /// Storage for: https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerGlobalScope/skipWaiting
    public internal(set) var skipWaitingStatus: Bool = false
}
