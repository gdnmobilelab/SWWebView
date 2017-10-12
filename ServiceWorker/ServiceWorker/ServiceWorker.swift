import Foundation
import JavaScriptCore
import PromiseKit

@objc public class ServiceWorker: NSObject {

    public let url: URL
    public let id: String

    public weak var delegate: ServiceWorkerDelegate?
    public weak var clientsDelegate: ServiceWorkerClientsDelegate?
    public var cacheStorage: CacheStorage?

    public var registration: ServiceWorkerRegistrationProtocol?

    fileprivate var _installState: ServiceWorkerInstallState

    public var state: ServiceWorkerInstallState {
        get {
            return self._installState
        }
        set(value) {
            if self._installState != value {
                self._installState = value
                self.setJSContextDebuggingName()
                GlobalEventLog.notifyChange(self)
            }
        }
    }

    fileprivate func setJSContextDebuggingName() {
        if let exec = self._executionEnvironment {
            exec.jsContextName = "\(url.absoluteString) (\(state.rawValue))"
        }
    }

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

    @objc public init(id: String, url: URL, state: String) throws {
        self.id = id
        self.url = url

        guard let installState = ServiceWorkerInstallState(rawValue: state) else {
            throw ErrorMessage("Could not parse install state string")
        }

        _installState = installState
        super.init()
    }

    fileprivate var isDestroyed = false
    @objc public func destroy() {
        isDestroyed = true
    }

    fileprivate var _executionEnvironment: ServiceWorkerExecutionEnvironment?

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

        if isDestroyed {
            return Promise(error: ErrorMessage("Worker has been destroyed"))
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
                    fulfill(env)
                    NSLog("perform?")
                    //                    env.perform(#selector(ServiceWorkerExecutionEnvironment.run), on: Thread.current, with: nil, waitUntilDone: false)
                    env.run()
                    NSLog("okay!")
                    //                    env = nil
                    //                    env.run()
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
            // As mentioned above, this is set to ensure we don't have two environments
            // created for one worker

            let finalChain = promise
                .then { (_) -> ServiceWorkerExecutionEnvironment in
                    self._executionEnvironment = env
                    return env
                }

            self.loadingExecutionEnvironmentPromise = finalChain
            return finalChain
        }
    }

    //    public func evaluateScript(_ script: String) -> Promise<Void> {
    //
    //        return self.evaluateScript(script)
    //            .then { _ in
    //                ()
    //            }
    //    }

    deinit {
        NSLog("Garbage collect worker")
        if let exec = self._executionEnvironment {
            exec.perform(#selector(ServiceWorkerExecutionEnvironment.stop), on: exec.thread, with: nil, waitUntilDone: true)
            exec.shouldKeepRunning = false
        }
    }

    public func evaluateScript<T>(_ script: String) -> Promise<T> {

        return getExecutionEnvironment()
            .then { (exec: ServiceWorkerExecutionEnvironment) -> Promise<T> in

                let returnType: ServiceWorkerExecutionEnvironment.EvaluateReturnType = T.self == JSContextPromise.self ? .promise : .object

                let (promise, passthrough) = Promise<T>.makePassthrough()

                let call = ServiceWorkerExecutionEnvironment.EvaluateScriptCall(script: script, url: nil, passthrough: passthrough, returnType: returnType)

                exec.perform(#selector(ServiceWorkerExecutionEnvironment.evaluateScript), on: exec.thread, with: call, waitUntilDone: false)

                return promise
            }
    }

    public func withJSContext(_ cb: @escaping (JSContext) throws -> Void) -> Promise<Void> {

        let call = ServiceWorkerExecutionEnvironment.WithJSContextCall(cb)

        return self.getExecutionEnvironment()
            .then { exec in
                exec.perform(#selector(ServiceWorkerExecutionEnvironment.withJSContext), on: exec.thread, with: call, waitUntilDone: false)
                return call.resolveVoid()
            }
    }

    public func dispatchEvent(_ event: Event) -> Promise<Void> {

        let call = ServiceWorkerExecutionEnvironment.DispatchEventCall(event)

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

    public internal(set) var skipWaitingStatus: Bool = false
}
