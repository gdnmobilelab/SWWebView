import Foundation
import JavaScriptCore
import PromiseKit

/// The wrapper around JSContext that actually runs the ServiceWorker code. We keep this
/// separate from ServiceWorker itself so that we can create relatively lightwight ServiceWorker
/// classes in response to getRegistration() etc but only create the JS environment when needed.
@objc public class ServiceWorkerExecutionEnvironment: NSObject, ServiceWorkerGlobalScopeDelegate {

    unowned let worker: ServiceWorker

    // We use this in deinit, by which point the worker is gone
    let workerId: String

    /// The heart of it all - this is where our worker code lives.
    fileprivate let jsContext: JSContext

    /// The objects that populate the global scope/self in the worker environment.
    internal let globalScope: ServiceWorkerGlobalScope

    /// We enforce a dispatch queue on all the events we dispatch to the worker. Partially
    /// to ensure QoS and keep it off the main thread, but also to respect the queue being
    /// freezed when we run an importScripts() call.
    let dispatchQueue: DispatchQueue

    /// Adds setTimeout(), setInterval() etc. to the global scope. We keep a reference at
    /// this level because we need to cancel all timeouts when our execution environment
    /// is being garbage collected.
    let timeoutManager: TimeoutManager

    /// It seems like a good idea to keep all workers in the same virtual machine - it means
    /// they can exchange JSValues, so we could implmenent stuff like SharedArrayBuffer in
    /// communication between workers. We can't do the same inside SWWebView, though.
    fileprivate static var virtualMachine = JSVirtualMachine()

    // Since WebSQL connections retain an open connection as long as they are alive, we need to
    // keep track of them, in order to close them off on shutdown. JS garbage collection
    // is sometimes enough, but not always.
    internal var activeWebSQLDatabases = NSHashTable<WebSQLDatabase>.weakObjects()

    // ConstructableFetchResponse needs a reference to the dispatchQueue attached to any particular
    // JSContext. So we store that connection here, with weak memory so that they are automatically
    // removed when no longer in use.
    static var contextDispatchQueues = NSMapTable<JSContext, DispatchQueue>(keyOptions: NSPointerFunctions.Options.weakMemory, valueOptions: NSPointerFunctions.Options.weakMemory)

    var jsContextName: String {
        set(value) {
            self.jsContext.name = value
        }
        get {
            return self.jsContext.name
        }
    }

    @objc public init(_ worker: ServiceWorker) throws {
        self.worker = worker
        self.workerId = worker.id
        guard let virtualMachine = ServiceWorkerExecutionEnvironment.virtualMachine else {
            throw ErrorMessage("There is no virtual machine associated with ServiceWorkerExecutionEnvironment")
        }

        self.dispatchQueue = DispatchQueue(label: worker.id, qos: DispatchQoS.utility, attributes: [.concurrent], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.workItem, target: nil)

        jsContext = JSContext(virtualMachine: virtualMachine)

        ServiceWorkerExecutionEnvironment.contextDispatchQueues.setObject(self.dispatchQueue, forKey: jsContext)

        globalScope = try ServiceWorkerGlobalScope(context: jsContext, worker)
        timeoutManager = TimeoutManager(withQueue: dispatchQueue, in: jsContext)
        super.init()
        jsContext.exceptionHandler = { [unowned self] (_: JSContext?, error: JSValue?) in
            // Thrown errors don't error on the evaluateScript call (necessarily?), so after
            // evaluating, we need to check whether there is a new exception.
            // unowned is *required* to avoid circular references that mean this never gets garbage
            // collected
            self.currentException = error
        }

        globalScope.delegate = self
    }

    /// Sometimes we want to make sure that our worker has finished all execution before
    /// we shut it down.
    func ensureFinished() -> Promise<Void> {
        let allWebSQL = self.activeWebSQLDatabases.allObjects

        if allWebSQL.count == 0 {
            return Promise(value: ())
        }
        Log.info?("Waiting until \(allWebSQL.count) WebSQL connections close before we stop.")
        let mappedClosePromises = allWebSQL.map { $0.close() }

        return when(fulfilled: mappedClosePromises)
    }

    deinit {
        Log.info?("Closing execution environment for: \(self.workerId)")

        let allWebSQL = self.activeWebSQLDatabases.allObjects
            .filter { $0.connection.open == true }

        if allWebSQL.count > 0 {
            Log.info?("\(allWebSQL.count) open WebSQL connections when shutting down worker")
        }

        allWebSQL.forEach { $0.forceClose() }

        GlobalVariableProvider.destroy(forContext: self.jsContext)
        self.currentException = nil
        self.timeoutManager.stopAllTimeouts = true
        self.jsContext.exceptionHandler = nil
        JSGarbageCollect(self.jsContext.jsGlobalContextRef)
    }

    // Thrown errors don't error on the evaluateScript call (necessarily?), so after
    // evaluating, we need to check whether there is a new exception.
    internal var currentException: JSValue?

    fileprivate func throwExceptionIfExists() throws {
        if let exc = currentException {
            currentException = nil
            throw ErrorMessage("\(exc)")
        }
    }

    public func evaluateScript(_ script: String, withSourceURL: URL? = nil) -> Promise<JSValue?> {

        let (promise, fulfill, reject) = Promise<JSValue?>.pending()

        self.dispatchQueue.async {
            do {
                if self.currentException != nil {
                    throw ErrorMessage("Cannot run script while context has an exception")
                }

                let returnVal = self.jsContext.evaluateScript(script, withSourceURL: withSourceURL)

                try self.throwExceptionIfExists()

                fulfill(returnVal)
            } catch {
                reject(error)
            }
        }

        return promise
    }

    func openWebSQLDatabase(name: String) throws -> WebSQLDatabase {
        let db = try WebSQLDatabase.openDatabase(for: self.worker, name: name, withQueue: self.dispatchQueue)
        self.activeWebSQLDatabases.add(db)
        return db
    }

    func importScripts(urls: [URL]) throws {

        dispatchPrecondition(condition: .onQueue(self.dispatchQueue))

        guard let url = urls.first else {
            // We've finished the array
            return
        }

        guard let loadFunction = self.worker.delegate?.serviceWorker else {
            throw ErrorMessage("Worker delegate does not implement importScripts")
        }

        let semaphore = DispatchSemaphore(value: 0)

        var error: Error?
        var content: String?

        // Because we're freezing the worker thread, we need to start another one in order
        // to do the actual import. I'm sure there is a better way of doing this.

        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
            loadFunction(self.worker, url, self.dispatchQueue) { err, body in
                if err != nil {
                    error = err
                } else {
                    content = body
                }
                semaphore.signal()
            }
        }

        semaphore.wait()

        if let err = error {
            throw err
        } else if let hasContent = content {
            self.jsContext.evaluateScript(hasContent, withSourceURL: url)
            var mutableURLs = urls
            mutableURLs.removeFirst(1)
            return try importScripts(urls: mutableURLs)
        } else {
            throw ErrorMessage("Async code did not complete")
        }
    }

    /// We want to run our JSContext on its own thread, but every now and then we need to
    /// manually manipulate JSValues etc, so we can't use evaluateScript() directly. Instead,
    /// this lets us run a (synchronous) piece of code on the correct thread.
    public func withJSContext(_ cb: @escaping (JSContext) throws -> Void) -> Promise<Void> {

        let (promise, fulfill, reject) = Promise<Void>.pending()

        self.dispatchQueue.async {
            do {
                try cb(self.jsContext)
                try self.throwExceptionIfExists()
                fulfill(())
            } catch {
                reject(error)
            }
        }

        return promise
    }

    public func dispatchEvent(_ event: Event) -> Promise<Void> {

        let (promise, fulfill, reject) = Promise<Void>.pending()

        self.dispatchQueue.async {
            do {
                self.globalScope.dispatchEvent(event)
                try self.throwExceptionIfExists()

                fulfill(())
            } catch {
                reject(error)
            }
        }

        return promise
    }
}
