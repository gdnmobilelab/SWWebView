import Foundation
import JavaScriptCore

/// ServiceWorkerGlobalScope sits inside a ServiceWorkerExecutionEnvironment, and defines what functions and
/// variables will be both globally accessible, and available on the "self" variable. (e.g.
/// self.addEventListener() and addEventListener() both work).
@objc class ServiceWorkerGlobalScope: EventTarget {

    let console: ConsoleMirror
    unowned let worker: ServiceWorker
    unowned let context: JSContext
    let clients: Clients
    let location: WorkerLocation

    weak var delegate: ServiceWorkerGlobalScopeDelegate?

    /// The ServiceWorker project doesn't define a ServiceWorkerRegistration object, it just defines
    /// a protocol for another project to implement. If one isn't defined and the client code tries
    /// to access it, we throw an error.
    var registration: ServiceWorkerRegistrationProtocol? {
        if self.worker.registration == nil {
            if let context = JSContext.current() {
                if let error = JSValue(newErrorFromMessage: "ServiceWorker has no registration attached", in: context) {
                    context.exception = error
                }
            }
        }
        return self.worker.registration
    }

    init(context: JSContext, _ worker: ServiceWorker) throws {

        self.console = try ConsoleMirror(in: context)
        self.worker = worker
        self.context = context
        self.clients = Clients(for: worker)

        if let workerLocation = WorkerLocation(withURL: worker.url) {
            self.location = workerLocation
        } else {

            // There's really no reason why this would ever happen, but URLComponents.init
            // returns an optional so we need to cover the possibility.

            throw ErrorMessage("Could not create worker location for this URL")
        }

        super.init()

        try self.attachVariablesToContext()
        try self.loadIndexedDBShim()
    }

    deinit {
        self.console.cleanup()
    }

    fileprivate func attachVariablesToContext() throws {

        // Annoyingly, we can't change the globalObject to be a reference to this. Instead, we have to take
        // all the attributes from the global scope and manually apply them to the existing global object.

        GlobalVariableProvider.addSelf(to: self.context)

        let skipWaiting: @convention(block) () -> Void = { [unowned self] in
            self.delegate?.skipWaiting()
        }

        let importAsConvention: @convention(block) () -> Void = { [unowned self] in
            self.importScripts()
        }

        let fetchAsConvention: @convention(block) (JSValue) -> JSValue? = { [unowned self] requestOrURL in
            self.delegate?.fetch(requestOrURL)
        }

        GlobalVariableProvider.add(variable: ConstructableEvent.self, to: self.context, withName: "Event")
        GlobalVariableProvider.add(variable: skipWaiting, to: self.context, withName: "skipWaiting")
        GlobalVariableProvider.add(variable: self.clients, to: self.context, withName: "clients")
        GlobalVariableProvider.add(variable: self.location, to: self.context, withName: "location")
        GlobalVariableProvider.add(variable: importAsConvention, to: self.context, withName: "importScripts")
        GlobalVariableProvider.add(variable: fetchAsConvention, to: self.context, withName: "fetch")
        GlobalVariableProvider.add(variable: FetchRequest.self, to: self.context, withName: "Request")
        GlobalVariableProvider.add(variable: FetchResponseProxy.self, to: self.context, withName: "Response")
        GlobalVariableProvider.add(variable: MessageChannel.self, to: self.context, withName: "MessageChannel")
        GlobalVariableProvider.add(variable: SWMessagePort.self, to: self.context, withName: "MessagePort")
        // These have weird hacks involving hash get/set, so we have specific functions
        // for adding them.
        GlobalVariableProvider.add(variable: try JSURL.createJSValue(for: self.context), to: self.context, withName: "URL")
        GlobalVariableProvider.add(variable: try WorkerLocation.createJSValue(for: self.context), to: self.context, withName: "WorkerLocation")

        if let storage = self.worker.cacheStorage {

            // Cache storage is provided through a delegate, which might not exist. So, if it does
            // then we add the object itself:

            GlobalVariableProvider.add(variable: storage, to: self.context, withName: "caches")

            // And also the prototypes - no real reason to do this, but you never know when some code might
            // be sniffing to see if CacheStorage is undefined, or something.

            GlobalVariableProvider.add(variable: type(of: storage), to: self.context, withName: "CacheStorage")
            GlobalVariableProvider.add(variable: type(of: storage).CacheClass, to: self.context, withName: "Cache")

        } else {

            // Otherwise we add a "special" property that throws an error when accessed.

            GlobalVariableProvider.add(missingPropertyWithError: "CacheStorage has not been provided for this worker", to: self.context, withName: "caches")
        }

        // We also want to add the addEventListener etc. functions to the global scope:

        EventTarget.applyJavaScriptListeners(self, to: self.context)
    }

    #if DEBUG

        /// We don't actually provide WebSQL in the worker environment (it's deprecated) but it is used to back
        /// our IndexedDB storage. We store the variable here solely so we can run tests on it.
        internal var webSQLOpenDatabaseFunction: Any?

    #endif

    /// Congratulations, you have found maybe the ugliest part of the project! Rather than implement the
    /// entire IndexedDB API myself (which I do not understand at all) I've instead implemented the WebSQL
    /// API (which is simple enough for me to understand) then provided IndexedDB through a shim library:
    /// https://github.com/axemclion/IndexedDBShim
    /// It's over 100KB, even minified, so it would be great to get rid of it some day.
    fileprivate func loadIndexedDBShim() throws {

        let file = Bundle(for: ServiceWorkerGlobalScope.self).bundleURL
            .appendingPathComponent("js-dist", isDirectory: true)
            .appendingPathComponent("indexeddbshim.js")

        let contents = try String(contentsOf: file)

        guard let targetObj = JSValue(newObjectIn: context) else {
            throw ErrorMessage("Could not create a new object in JSContext")
        }

        guard let shimFunction = context.evaluateScript("(function() {\(contents); return indexeddbshim;})()") else {
            throw ErrorMessage("Could not extract IndexedDBShim function from JS file")
        }

        // The shim is designed add variables to a "window" object. But our environment is a bit weird, and we can't
        // just add variables to self and have them be globally accesssible. So instead, we get the shim to apply
        // onto an empty project, then read the keys it's added back out, and send them to our GlobalVariableProvider.

        let openDatabaseFunction: @convention(block) (String, String, String, Int, JSValue?) -> WebSQLDatabase? = { [unowned self] name, _, _, _, _ in

            // WebSQL's openDatabase() function has four arguments: name, version, displayName and estimatedSize.
            // We/the shim only really care about the name, so we just ignore the rest.

            do {
                guard let db = try self.delegate?.openWebSQLDatabase(name: name) else {
                    throw ErrorMessage("Delegate does not provide WebSQL databaes")
                }
                return db
            } catch {
                guard let jsc = JSContext.current() else {
                    Log.error?("Tried to call WebSQL openDatabase outside of a JSContext?")
                    return nil
                }

                let err = JSValue(newErrorFromMessage: "\(error)", in: jsc)
                jsc.exception = err
                Log.error?("\(error)")
                return nil
            }
        }

        #if DEBUG
            // make the openDatabase function available for tests
            self.webSQLOpenDatabaseFunction = openDatabaseFunction
        #endif

        var debug = false

        #if DEBUG
            debug = true
        #endif

        // This is the configuration object specified here: https://github.com/axemclion/IndexedDBShim#user-content-configuration-options

        let config: [String: Any] = [
            "DEBUG": debug,
            "win": [
                "openDatabase": openDatabaseFunction
            ]
        ]

        // Documentation for the function we're calling is under setGlobalVars here:
        // https://github.com/axemclion/IndexedDBShim#user-content-setglobalvarswinobj-or-null-initialconfig

        shimFunction.call(withArguments: [targetObj, config])

        // Now that we've applied the function to targetObj, we can go back and get all the
        // properties that have been added to the previously empty object, and reapply to
        // the global scope.

        guard let keys = context.objectForKeyedSubscript("Object")
            .objectForKeyedSubscript("getOwnPropertyNames")
            .call(withArguments: [targetObj])
            .toArray() as? [String] else {
            throw ErrorMessage("Could not get keys of indexeddb shim")
        }

        keys.forEach { key in

            if key == "shimIndexedDB" {
                // The shim makes its own custom key that we don't need to replicate
                return
            }

            GlobalVariableProvider.add(variable: targetObj.objectForKeyedSubscript(key), to: self.context, withName: key)
        }
    }

    /// Imports other scripts into the global scope of the worker. This part just parses
    /// the strings into URLs, then passes to the delegate (almost always ServiceWorkerExecutionEnvironment)
    internal func importScripts() {
        do {

            guard let delegate = self.delegate else {
                throw ErrorMessage("No global scope delegate set, cannot import scripts")
            }

            // importScripts() can have any number of arguments, so rather than specify them
            // in the function parameters, we use currentArguments()

            guard let args = JSContext.currentArguments() as? [JSValue] else {
                throw ErrorMessage("Could not get current context arguments")
            }

            let scriptURLStrings = try args.map { jsVal -> String in

                // All the arguments passed in must be strings, if they're not, we'll throw
                // an error

                guard let stringVal = jsVal.toString() else {
                    throw ErrorMessage("Could not convert argument to a string")
                }
                return stringVal
            }

            let scriptURLs = try scriptURLStrings.map { urlString -> URL in

                // Now that we've got strings, we need to then them into URLs that are
                // relative to the worker URL.

                guard let asURL = URL(string: urlString, relativeTo: self.worker.url) else {
                    throw ErrorMessage("Could not parse URL: " + urlString)
                }
                return asURL
            }

            try delegate.importScripts(urls: scriptURLs)

        } catch {
            let jsError = JSValue(newErrorFromMessage: "\(error)", in: context)
            context.exception = jsError
        }
    }
}
