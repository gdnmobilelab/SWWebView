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
            return exec.ensureFinished()
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

    internal func getExecutionEnvironment() -> Promise<ServiceWorkerExecutionEnvironment> {

        if let exec = _executionEnvironment {
            return Promise(value: exec)
        }

        if isDestroyed {
            return Promise(error: ErrorMessage("Worker has been destroyed"))
        }

        // Being lazy means that we can create instances of ServiceWorker whenever we feel
        // like it (like, say, when ServiceWorkerRegistration is populating active, waiting etc)
        // without incurring a huge penalty for doing so.

        Log.info?("Creating execution environment for worker: " + id)

        return firstly {
            let env = try ServiceWorkerExecutionEnvironment(self)

            guard let delegate = self.delegate else {
                throw ErrorMessage("This worker has no delegate to load content through")
            }

            let script = try delegate.serviceWorkerGetScriptContent(self)
            return env.evaluateScript(script, withSourceURL: self.url)
                .then { _ -> ServiceWorkerExecutionEnvironment in
                    // return value doesn't really mean anything here
                    self._executionEnvironment = env
                    self.setJSContextDebuggingName()
                    return env
                }
        }
    }

    public func evaluateScript(_ script: String) -> Promise<JSValue?> {

        return getExecutionEnvironment()
            .then { exec in
                exec.evaluateScript(script)
            }
    }

    public func withJSContext(_ cb: @escaping (JSContext) throws -> Void) -> Promise<Void> {

        if let exec = self._executionEnvironment {
            return exec.withJSContext(cb)
        } else {
            return self.getExecutionEnvironment()
                .then { exec in
                    exec.withJSContext(cb)
                }
        }
    }

    @objc func evaluateScript(_ script: String, callback: @escaping (Error?, JSValue?) -> Void) {
        evaluateScript(script)
            .then { val in
                callback(nil, val)
            }
            .catch { err in
                callback(err, nil)
            }
    }

    //    internal func withExecutionEnvironment(_ cb: @escaping (ServiceWorkerExecutionEnvironment) throws -> Void) -> Promise<Void> {
    //        if let exec = self._executionEnvironment {
    //            do {
    //                try cb(exec)
    //                return Promise(value: ())
    //            } catch {
    //                return Promise(error: error)
    //            }
    //        }
    //        return getExecutionEnvironment()
    //            .then { exec in
    //                try cb(exec)
    //            }
    //    }

    public func dispatchEvent(_ event: Event) -> Promise<Void> {

        if let exec = self._executionEnvironment {
            return exec.dispatchEvent(event)
        } else {
            return self.getExecutionEnvironment()
                .then { exec in
                    exec.dispatchEvent(event)
                }
        }
    }

    public var skipWaitingStatus: Bool {
        if let exec = self._executionEnvironment {
            return exec.globalScope.skipWaitingStatus
        } else {
            return false
        }
    }
}
