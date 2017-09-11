//
//  ServiceWorkerGlobalScope.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

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

        self.console = try ConsoleMirror(console: context.objectForKeyedSubscript("console"))
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
    }

    deinit {
        let allWebSQL = self.activeWebSQLDatabases.allObjects
        if allWebSQL.count > 0 {
            Log.info?("\(allWebSQL.count) open WebSQL connections when shutting down worker")
            allWebSQL.forEach { $0.close() }
        }
    }

    //    func fetch(requestOrURL: JSValue, options: JSValue?) -> JSValue? {
    //        return FetchOperation.jsFetch(context: self.context, origin: self.worker.url, requestOrURL: requestOrURL, options: options)
    //    }

    fileprivate func attachVariablesToContext() throws {

        // Annoyingly, we can't change the globalObject to be a reference to this. Instead, we have to take
        // all the attributes from the global scope and manually apply them to the existing global object.

        self.context.globalObject.setValue(self.context.globalObject, forProperty: "self")

        self.context.globalObject.setValue(Event.self, forProperty: "Event")

        let skipWaiting: @convention(block) () -> Void = { [unowned self] in
            self.skipWaitingStatus = true
        }

        self.context.globalObject.setValue(skipWaiting, forProperty: "skipWaiting")
        self.context.globalObject.setValue(self.clients, forProperty: "clients")
        self.context.globalObject.setValue(self.location, forProperty: "location")

        let importAsConvention: @convention(block) (JSValue) -> Void = { [unowned self] scripts in
            self.importScripts(scripts)
        }
        self.context.globalObject.setValue(importAsConvention, forProperty: "importScripts")

        let fetchAsConvention: @convention(block) (JSValue, JSValue?) -> JSValue? = { [unowned self] requestOrURL, _ in

            FetchSession.default.fetch(requestOrURL, fromOrigin: self.worker.url)

            //            FetchOperation.jsFetch(context: self.context, origin: self.worker.url, requestOrURL: requestOrURL, options: options)
        }
        self.context.globalObject.setValue(fetchAsConvention, forProperty: "fetch")
        self.context.globalObject.setValue(FetchRequest.self, forProperty: "Request")

        // These have weird hacks involving hash get/set, so we have specific functions
        // for adding them.
        try JSURL.addToWorkerContext(context: self.context)
        try WorkerLocation.addToWorkerContext(context: self.context)

        applyListenersTo(jsObject: self.context.globalObject)
    }

    // Since these retain an open connection as long as they are alive, we need to
    // keep track of them, in order to close them off on shutdown. JS garbage collection
    // is sometimes enough, but not always.
    internal var activeWebSQLDatabases = NSHashTable<WebSQLDatabase>.weakObjects()

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
                let db = try WebSQLDatabase.openDatabase(for: self.worker, name: name)
                // we have to track these to make sure they are all closed when the worker
                // is destroyed
                self.activeWebSQLDatabases.add(db)
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

            self.context.globalObject.setValue(targetObj.objectForKeyedSubscript(key), forProperty: key)
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

    internal func importScripts(_ scripts: JSValue) {
        do {

            guard let delegate = self.delegate else {
                throw ErrorMessage("No global scope delegate set, cannot import scripts")
            }

            var scriptURLStrings: [String]

            // importScripts supports both single files and arrays

            if scripts.isArray {
                guard let scriptsArray = scripts.toArray() as? [String] else {
                    throw ErrorMessage("Could not parse array sent in to importScripts()")
                }
                scriptURLStrings = scriptsArray
            } else if scripts.isString {
                guard let singleScript = scripts.toString() else {
                    throw ErrorMessage("Could not parse string sent in to importScripts()")
                }
                scriptURLStrings = [singleScript]
            } else {
                throw ErrorMessage("Could not parse arguments passed to importScripts()")
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
