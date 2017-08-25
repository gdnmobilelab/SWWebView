//
//  ServiceWorkerGlobalScope.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol ServiceWorkerGlobalScopeExports: JSExport {
    var registration: ServiceWorkerRegistrationProtocol { get }
    func skipWaiting()
    func importScripts(_: JSValue)
    func fetch(requestOrURL: JSValue, options: JSValue?) -> JSValue
    var clients: Clients { get }
    var location: WorkerLocation { get }
}

@objc class ServiceWorkerGlobalScope: EventTarget, ServiceWorkerGlobalScopeExports {

    let console: ConsoleMirror
    unowned let worker: ServiceWorker
    unowned let context: JSContext
    let clients: Clients
    let location: WorkerLocation

    var skipWaitingStatus = false

    func skipWaiting() {
        self.skipWaitingStatus = true
    }

    var registration: ServiceWorkerRegistrationProtocol {
        return self.worker.registration
    }

    init(context: JSContext, _ worker: ServiceWorker) throws {

        self.console = ConsoleMirror(console: context.objectForKeyedSubscript("console"))
        self.worker = worker
        self.context = context
        self.clients = Clients(for: worker, in: context)
        self.location = WorkerLocation(withURL: worker.url, inContext: context)!

        super.init()

        self.attachVariablesToContext()
        try self.loadIndexedDBShim()
    }

    func fetch(requestOrURL: JSValue, options: JSValue?) -> JSValue {
        return FetchOperation.jsFetch(context: self.context, origin: self.worker.url, requestOrURL: requestOrURL, options: options)
    }

    fileprivate func attachVariablesToContext() {

        // Annoyingly, we can't change the globalObject to be a reference to this. Instead, we have to take
        // all the attributes from the global scope and manually apply them to the existing global object.

        self.context.globalObject.setValue(self, forProperty: "self")

        self.context.globalObject.setValue(Event.self, forProperty: "Event")
        self.context.globalObject.setValue(skipWaiting as @convention(block) () -> Void, forProperty: "skipWaiting")
        self.context.globalObject.setValue(self.clients, forProperty: "clients")
        self.context.globalObject.setValue(self.location, forProperty: "location")

        let importAsConvention: @convention(block) (JSValue) -> Void = importScripts
        self.context.globalObject.setValue(importAsConvention, forProperty: "importScripts")

        let fetchAsConvention: @convention(block) (JSValue, JSValue?) -> JSValue = fetch
        self.context.globalObject.setValue(fetchAsConvention, forProperty: "fetch")
        self.context.globalObject.setValue(FetchRequest.self, forProperty: "Request")

        // These have weird hacks involving hash get/set, so we have specific functions
        // for adding them.
        JSURL.addToWorkerContext(context: self.context)
        WorkerLocation.addToWorkerContext(context: self.context)

        self.applyListenersTo(jsObject: self.context.globalObject)
    }

    fileprivate func loadIndexedDBShim() throws {

        let file = Bundle(for: ServiceWorkerGlobalScope.self).bundleURL
            .appendingPathComponent("js-dist", isDirectory: true)
            .appendingPathComponent("indexeddbshim.js")

        let contents = try String(contentsOf: file)

        let targetObj = JSValue(newObjectIn: self.context)!

        let shimFunction = self.context.evaluateScript("(function() {\(contents); return indexeddbshim;})()")!

        // We use targetObj as the "window" object to apply the shim to. Then we read the keys
        // back out and apply them to our global object (so that you can use "indexedDB" as well as
        // "self.indexedDB")

        let config: [String: Any] = [
            "DEBUG": true,
            "win": [
                "openDatabase": WebSQLDatabase.createOpenDatabaseFunction(for: self.worker.url),
            ],
        ]

        // Documentation for the function we're calling is under setGlobalVars here:
        // https://github.com/axemclion/IndexedDBShim

        shimFunction.call(withArguments: [targetObj, config])

        let keys = self.context.objectForKeyedSubscript("Object")
            .objectForKeyedSubscript("getOwnPropertyNames")
            .call(withArguments: [targetObj])
            .toArray() as! [String]

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

            var scriptURLStrings: [String]

            // importScripts supports both single files and arrays
            if scripts.isArray {
                scriptURLStrings = scripts.toArray() as! [String]
            } else {
                scriptURLStrings = [scripts.toString()]
            }

            let scriptURLs = try scriptURLStrings.map { urlString -> URL in
                let asURL = URL(string: urlString, relativeTo: self.worker.url)
                if asURL == nil {
                    throw ErrorMessage("Could not parse URL: " + urlString)
                }
                return asURL!
            }

            let scripts = try worker.importScripts(worker, scriptURLs)

            scripts.enumerated().forEach { arg in
                self.context.evaluateScript(arg.element, withSourceURL: scriptURLs[arg.offset])
            }

        } catch {
            self.throwErrorIntoJSContext(error: error)
        }
    }
}
