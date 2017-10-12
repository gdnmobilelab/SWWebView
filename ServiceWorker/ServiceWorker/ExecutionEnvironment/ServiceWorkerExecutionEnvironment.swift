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

        // WebSQL connections stay open until they are garbage collected, so we need to manually
        // shut them down when the worker is done. We add to keep track of active DBs:

        self.activeWebSQLDatabases.add(db)
        return db
    }

    /// Importing scripts is relatively complicated because it involves freezing the worker
    /// thread entirely while we fetch the contents of our scripts. We use a DispatchSemaphore
    /// to do that, while running our delegate function on another queue.
    func importScripts(urls: [URL]) throws {

        self.checkOnThread()

        // We actually loop through the URL array, calling importScripts() over and over, removing
        // a URL each time. The main reason for doing this is to keep memory usage low - in theory
        // these JS files could be hundreds of KB big, so rather than load them all into memory
        // we just do them one at a time.

        guard let url = urls.first else {
            // We've finished the array
            return
        }

        // It's possible that our delegate doesn't implement script imports. If so we throw out
        // immediately

        guard let loadFunction = self.worker.delegate?.serviceWorker else {
            throw ErrorMessage("Worker delegate does not implement importScripts")
        }

        // This is what controls out thread freezing.

        let semaphore = DispatchSemaphore(value: 0)

        // Because we're going to execute the load function asynchoronously on another
        // queue, we need to have a way of passing the results back to our current context.
        // So, we declare these variables to store the results in:

        var error: Error?
        var content: String?

        // Now we spin off a new dispatch queue and run out load function in it:

        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
            loadFunction(self.worker, url) { err, body in
                if err != nil {
                    error = err
                } else {
                    content = body
                }

                // This call resumes our thread. But because this is asynchronous, this
                // line will run after...

                semaphore.signal()
            }
        }

        // ...this one, which contains the command to freeze our main thread.

        semaphore.wait()

        // at this point our async function has executed and stored its results in the
        // variables we created. Now we act on those variables:

        if let err = error {
            throw err
        } else if let hasContent = content {

            // Provide our import has run successfully, we can now actually evaluate
            // the script. withSourceURL means that the source in Safari debugger will
            // be attributed correctly.

            self.jsContext.evaluateScript(hasContent, withSourceURL: url)

            if let exception = self.jsContext.exception {

                // If an error occurred in the process of importing the script,
                // bail out

                throw ErrorMessage("\(exception)")
            }

            // Now that we've successfully imported this script, we remove it from our
            // array of scripts and run again.

            var mutableURLs = urls
            mutableURLs.removeFirst(1)
            return try self.importScripts(urls: mutableURLs)

        } else {

            // It's actually possible for a faulty delegate to return neither an error
            // nor a result. So we need to factor that in.

            throw ErrorMessage("importScripts loader did not return content, but did not return an error either")
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

    /// Send an event (of any kind, ExtendableEvent etc.) into the worker. This is the way
    /// the majority of triggers are set in the worker context. Like evaluateScript, it must
    /// be called on the worker thread, which ServiceWorker does.
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

    /// Global scope delegate for running a remote fetch. Maybe we should set up worker-specific
    /// FetchSessions that run on the worker thread, not sure really.
    func fetch(_ requestOrString: JSValue) -> JSValue? {
        return FetchSession.default.fetch(requestOrString, fromOrigin: self.worker.url)
    }

    /// Part of the Service Worker spec: https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerGlobalScope/skipWaiting
    /// is fired during install events to make sure the worker takes control of its scope immediately.
    func skipWaiting() {
        self.worker.skipWaitingStatus = true
    }
}
