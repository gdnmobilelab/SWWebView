//
//  ServiceWorkerExecutionEnvironment.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc public class ServiceWorkerExecutionEnvironment: NSObject, ServiceWorkerGlobalScopeDelegate {

    unowned let worker: ServiceWorker
    fileprivate let jsContext: JSContext
    internal let globalScope: ServiceWorkerGlobalScope
    let dispatchQueue = DispatchQueue.global(qos: .background)
    let timeoutManager: TimeoutManager

    fileprivate static var virtualMachine = JSVirtualMachine()!

    #if DEBUG
        // We use this in tests to check whether all our JSContexts have been
        // garbage collected or not. We don't need it in production environments.
        static var allJSContexts = NSHashTable<JSContext>.weakObjects()
    #endif

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
        self.jsContext = JSContext(virtualMachine: ServiceWorkerExecutionEnvironment.virtualMachine)
        // We use this in tests to ensure all JSContexts get cleared up. Should put behind a debug flag.

        #if DEBUG
            ServiceWorkerExecutionEnvironment.allJSContexts.add(self.jsContext)
        #endif

        self.globalScope = try ServiceWorkerGlobalScope(context: self.jsContext, worker)
        self.timeoutManager = TimeoutManager(withQueue: self.dispatchQueue, in: self.jsContext)
        super.init()
        self.jsContext.exceptionHandler = { [unowned self] (_: JSContext?, error: JSValue?) in
            // Thrown errors don't error on the evaluateScript call (necessarily?), so after
            // evaluating, we need to check whether there is a new exception.
            // unowned is *required* to avoid circular references that mean this never gets garbage
            // collected
            self.currentException = error
        }

        self.globalScope.delegate = self
    }

    deinit {
        NSLog("Deinit execution environment: Garbage collect.")
        self.currentException = nil
        self.timeoutManager.stopAllTimeouts = true
        self.jsContext.exceptionHandler = nil
        JSGarbageCollect(self.jsContext.jsGlobalContextRef)
    }

    // Thrown errors don't error on the evaluateScript call (necessarily?), so after
    // evaluating, we need to check whether there is a new exception.
    internal var currentException: JSValue?

    fileprivate func throwExceptionIfExists() throws {
        if self.currentException != nil {
            let exc = self.currentException!
            self.currentException = nil
            if let msg = exc.objectForKeyedSubscript("message") {
                throw ErrorMessage(msg.toString())
            }
            throw ErrorMessage(exc.toString())
        }
    }

    public func evaluateScript(_ script: String, withSourceURL: URL? = nil) -> Promise<JSValue?> {

        return Promise(value: ())
            .then(on: self.dispatchQueue, execute: { () -> JSValue? in
                if self.currentException != nil {
                    throw ErrorMessage("Cannot run script while context has an exception")
                }

                let returnVal = self.jsContext.evaluateScript(script, withSourceURL: withSourceURL)

                try self.throwExceptionIfExists()

                return returnVal
            })
    }

    func importScripts(urls: [URL]) throws {

        self.dispatchQueue.sync {

            // We want our worker execution thread to pause at this point, so that
            // we can do remote fetching of content.

            let semaphore = DispatchSemaphore(value: 0)

            var error: Error?
            var scripts: [String]?

            DispatchQueue.global().async {

                // Now, outside of our worker thread, we fetch the scripts

                if self.worker.delegate?.serviceWorker?(self.worker, importScripts: urls, { err, importedScripts in
                    error = err
                    scripts = importedScripts

                    // With the variables set, we can now resume on our worker thread.
                    semaphore.signal()
                }) == nil {
                    error = ErrorMessage("ServiceWorkerDelegate does not implement importScript")
                    semaphore.signal()
                }
            }

            // Wait for the above code to execute
            semaphore.wait()

            // Now we have our scripts (or error) and can process.
            do {
                if let err = error {
                    throw err
                }

                guard let allScripts = scripts else {
                    throw ErrorMessage("importScripts() returned no error, but no scripts either")
                }

                try allScripts.enumerated().forEach { idx, script in

                    if idx > urls.count - 1 {
                        throw ErrorMessage("More scripts were returned than were requested")
                    }

                    let scriptURL = urls[idx]

                    self.jsContext.evaluateScript(script, withSourceURL: scriptURL)
                }

            } catch {
                let jsError = JSValue(newErrorFromMessage: "\(error)", in: self.jsContext)
                self.jsContext.exception = jsError
            }
        }
    }

    /// We want to run our JSContext on its own thread, but every now and then we need to
    /// manually manipulate JSValues etc, so we can't use evaluateScript() directly. Instead,
    /// this lets us run a (synchronous) piece of code on the correct thread.
    public func withJSContext(_ cb: @escaping (JSContext) throws -> Void) -> Promise<Void> {

        return Promise(value: ())
            .then(on: self.dispatchQueue, execute: { () -> Void in
                try cb(self.jsContext)
                try self.throwExceptionIfExists()
            })
    }

    public func dispatchEvent(_ event: Event) -> Promise<Void> {

        return Promise(value: ())
            .then(on: self.dispatchQueue, execute: { () -> Void in
                self.globalScope.dispatchEvent(event)
                try self.throwExceptionIfExists()
            })
    }
}
