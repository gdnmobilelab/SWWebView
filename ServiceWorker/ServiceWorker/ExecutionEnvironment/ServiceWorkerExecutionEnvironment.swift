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
    fileprivate var jsContext: JSContext!

    /// The objects that populate the global scope/self in the worker environment.
    fileprivate let globalScope: ServiceWorkerGlobalScope

    internal let thread: Thread

    /// Adds setTimeout(), setInterval() etc. to the global scope. We keep a reference at
    /// this level because we need to cancel all timeouts when our execution environment
    /// is being garbage collected.
    fileprivate let timeoutManager: TimeoutManager

    // Since WebSQL connections retain an open connection as long as they are alive, we need to
    // keep track of them, in order to close them off on shutdown. JS garbage collection
    // is sometimes enough, but not always.
    fileprivate var activeWebSQLDatabases = NSHashTable<WebSQLDatabase>.weakObjects()

    // Various clases that interact with the worker context need a reference to the environment attached to any particular
    // JSContext. So we store that connection here, with weak memory so that they are automatically
    // removed when no longer in use.
    static var contexts = NSMapTable<JSContext, ServiceWorkerExecutionEnvironment>(keyOptions: NSPointerFunctions.Options.weakMemory, valueOptions: NSPointerFunctions.Options.weakMemory)

    /// We use this at various points to ensure that functions available in a JSContext are called on the right thread.
    /// Right now it'll throw a fatal error if they aren't, to help with debugging, but maybe we can do something better
    /// than that.
    public static func ensureContextIsOnCorrectThread() {
        let thread = self.contexts.object(forKey: JSContext.current())?.thread
        if thread != Thread.current {
            fatalError("Not executing on context thread")
        }
    }

    // This controls the title that appears in the Safari debugger - helpful to indentify
    // which worker you are looking at when multiple are running at once.
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

        self.thread = Thread.current

        // This shows up in the XCode debugger, helps us to identify the worker thread
        self.thread.name = "ServiceWorker:" + self.workerId

        // Haven't really profiled the difference, but this seems like the category that makes
        // the most sense for a worker
        self.thread.qualityOfService = QualityOfService.utility

        self.jsContext = JSContext()

        self.globalScope = try ServiceWorkerGlobalScope(context: self.jsContext, worker)
        self.timeoutManager = TimeoutManager(for: Thread.current, in: self.jsContext)

        super.init()

        // We keep track of the Context -> ExecEnvironment mapping for the static ensure call
        ServiceWorkerExecutionEnvironment.contexts.setObject(self, forKey: self.jsContext)

        self.jsContext.exceptionHandler = { [unowned self] (_: JSContext?, error: JSValue?) in
            // Thrown errors don't error on the evaluateScript call (necessarily?), so after
            // evaluating, we need to check whether there is a new exception.
            // unowned is *required* to avoid circular references that mean this never gets garbage
            // collected
            self.currentException = error
        }

        self.globalScope.delegate = self
    }

    var shouldKeepRunning = true

    @objc func run() {
        self.checkOnThread()

        // I'm not super sure about all of this (need to read more) but this seems to do what we need - keeps
        // the worker thread alive by running RunLoop.current inside the worker thread. This function does not
        // return, as CFRunLoopRun() loops infinitely.
        CFRunLoopRun()
    }

    @objc func stop() {
        self.checkOnThread()

        // ...until we run stop() - CFRunLoopStop() kills the current run loop and allows the run() function
        // above to successfully return

        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    /// Sometimes we want to make sure that our worker has finished all execution before
    /// we shut it down. Need to flesh this out a lot more (what about timeouts?) but for now
    /// it ensures that all WebSQL databases clean up after themselves on close.
    @objc func ensureFinished(responsePromise: PromisePassthrough) {
        let allWebSQL = self.activeWebSQLDatabases.allObjects

        if allWebSQL.count == 0 {
            return responsePromise.fulfill(())
        }
        Log.info?("Waiting until \(allWebSQL.count) WebSQL connections close before we stop.")
        let mappedClosePromises = allWebSQL.map { $0.close() }

        when(fulfilled: mappedClosePromises)
            .then {
                NSLog("Closed WebSQL connections")
            }
            .passthrough(responsePromise)
    }

    deinit {
        Log.info?("Closing execution environment for: \(self.workerId)")
        self.shouldKeepRunning = false
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
            self.currentException = nil
            throw ErrorMessage("\(exc)")
        }
    }

    /// Similar to the ensureOnCurrentThread() static function, this is here to make sure that the calls
    /// we run from ServiceWorker by calling NSObject.perform() are actually being run on the correct thread.
    fileprivate func checkOnThread() {
        if Thread.current != self.thread {
            fatalError("Tried to execute worker code outside of worker thread")
        }
    }

    /// Actually run some JavaScript inside the worker context. evaluateScript() itself is
    /// synchronous, but ServiceWorker calls it without waiting for response (because this
    /// thread could be frozen) so we use the EvaluateScriptCall wrapper to asynchronously
    /// send back the response.
    @objc func evaluateScript(_ call: EvaluateScriptCall) {

        self.checkOnThread()

        do {
            if self.currentException != nil {
                throw ErrorMessage("Cannot run script while context has an exception")
            }

            let returnJSValue = self.jsContext.evaluateScript(call.script, withSourceURL: call.url)

            try self.throwExceptionIfExists()

            guard let returnExists = returnJSValue else {
                call.fulfill(nil)
                return
            }

            if call.returnType == .promise {
                call.fulfill(JSContextPromise(jsValue: returnExists, thread: self.thread))
            } else if call.returnType == .void {
                call.fulfill(nil)
            } else {
                call.fulfill(returnExists.toObject())
            }

        } catch {
            call.reject(error)
        }
    }

    func openWebSQLDatabase(name: String) throws -> WebSQLDatabase {
        self.checkOnThread()
        let db = try WebSQLDatabase.openDatabase(for: self.worker, in: self, name: name)
        self.activeWebSQLDatabases.add(db)
        return db
    }

    func importScripts(urls: [URL]) throws {

        self.checkOnThread()

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
            loadFunction(self.worker, url) { err, body in
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
            return try self.importScripts(urls: mutableURLs)
        } else {
            throw ErrorMessage("Async code did not complete")
        }
    }

    /// We want to run our JSContext on its own thread, but every now and then we need to
    /// manually manipulate JSValues etc, so we can't use evaluateScript() directly. Instead,
    /// this lets us run a (synchronous) piece of code on the correct thread.
    @objc internal func withJSContext(_ call: WithJSContextCall) {

        self.checkOnThread()
        do {
            try call.funcToRun(self.jsContext)
            call.fulfill(())
        } catch {
            call.reject(error)
        }
    }

    @objc func dispatchEvent(_ call: DispatchEventCall) {

        self.checkOnThread()
        self.globalScope.dispatchEvent(call.event)

        do {
            try self.throwExceptionIfExists()
            call.fulfill(nil)
        } catch {
            call.reject(error)
        }
    }

    func fetch(_ requestOrString: JSValue) -> JSValue? {
        return FetchSession.default.fetch(requestOrString, fromOrigin: self.worker.url)
    }

    func skipWaiting() {
        self.worker.skipWaitingStatus = true
    }
}
