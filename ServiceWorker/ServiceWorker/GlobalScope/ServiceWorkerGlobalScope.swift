import Foundation
import JavaScriptCore

@objc class ServiceWorkerGlobalScope: EventTarget {

    let console: ConsoleMirror
    unowned let worker: ServiceWorker
    unowned let context: JSContext
    let clients: Clients
    let location: WorkerLocation

    weak var delegate: ServiceWorkerGlobalScopeDelegate?

    var skipWaitingStatus = false

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
            throw ErrorMessage("Could not create worker location for this URL")
        }

        super.init()

        try self.attachVariablesToContext()
        try self.loadIndexedDBShim()

        if let storage = worker.cacheStorage {
            GlobalVariableProvider.add(variable: storage, to: context, withName: "caches")
            GlobalVariableProvider.add(variable: type(of: storage), to: context, withName: "CacheStorage")
            GlobalVariableProvider.add(variable: type(of: storage).CacheClass, to: context, withName: "Cache")
        } else {
            GlobalVariableProvider.add(missingPropertyWithError: "CacheStorage has not been provided for this worker", to: context, withName: "caches")
        }
    }

    deinit {
        self.console.cleanup()
    }

    fileprivate func attachVariablesToContext() throws {

        // Annoyingly, we can't change the globalObject to be a reference to this. Instead, we have to take
        // all the attributes from the global scope and manually apply them to the existing global object.

        GlobalVariableProvider.addSelf(to: self.context)

        let skipWaiting: @convention(block) () -> Void = { [unowned self] in
            self.skipWaitingStatus = true
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
        GlobalVariableProvider.add(variable: ConstructableFetchResponse.self, to: self.context, withName: "Response")
        GlobalVariableProvider.add(variable: MessageChannel.self, to: self.context, withName: "MessageChannel")
        GlobalVariableProvider.add(variable: SWMessagePort.self, to: self.context, withName: "MessagePort")
        // These have weird hacks involving hash get/set, so we have specific functions
        // for adding them.
        GlobalVariableProvider.add(variable: try JSURL.createJSValue(for: self.context), to: self.context, withName: "URL")
        GlobalVariableProvider.add(variable: try WorkerLocation.createJSValue(for: self.context), to: self.context, withName: "WorkerLocation")

        EventTarget.applyJavaScriptListeners(self, to: self.context)
    }

    // Storing here primarily for tests - we don't expose openDatabase globally, but sometimes
    // we want to use it.
    internal var openDatabaseFunction: Any?

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

        // We use targetObj as the "window" object to apply the shim to. Then we read the keys
        // back out and apply them to our global object (so that you can use "indexedDB" as well as
        // "self.indexedDB")

        let openDatabaseFunction: @convention(block) (String, String, String, Int, JSValue?) -> WebSQLDatabase? = { [unowned self] name, _, _, _, _ in

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

        let config: [String: Any] = [
            "DEBUG": true,
            "win": [
                "openDatabase": openDatabaseFunction
            ]
        ]

        self.openDatabaseFunction = openDatabaseFunction

        // Documentation for the function we're calling is under setGlobalVars here:
        // https://github.com/axemclion/IndexedDBShim

        shimFunction.call(withArguments: [targetObj, config])

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

    fileprivate func throwErrorIntoJSContext(error: Error) {
        var errMsg = String(describing: error)
        if let msg = error as? ErrorMessage {
            errMsg = msg.message
        }
        let err = JSValue(newErrorFromMessage: errMsg, in: context)
        context.exception = err
    }

    internal func importScripts() {
        do {

            guard let delegate = self.delegate else {
                throw ErrorMessage("No global scope delegate set, cannot import scripts")
            }

            guard let args = JSContext.currentArguments() as? [JSValue] else {
                throw ErrorMessage("Could not get current context arguments")
            }

            let scriptURLStrings = try args.map { jsVal -> String in

                guard let stringVal = jsVal.toString() else {
                    throw ErrorMessage("Could not convert argument to a string")
                }
                return stringVal
            }

            let scriptURLs = try scriptURLStrings.map { urlString -> URL in
                guard let asURL = URL(string: urlString, relativeTo: self.worker.url) else {
                    throw ErrorMessage("Could not parse URL: " + urlString)
                }
                return asURL
            }

            try delegate.importScripts(urls: scriptURLs)

            //            let scripts = try worker.implementations.importScripts(worker, scriptURLs)
            //
            //            scripts.enumerated().forEach { arg in
            //                self.context.evaluateScript(arg.element, withSourceURL: scriptURLs[arg.offset])
            //            }

        } catch {
            self.throwErrorIntoJSContext(error: error)
        }
    }
}
