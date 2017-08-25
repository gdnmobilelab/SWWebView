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

@objc public class ServiceWorkerExecutionEnvironment: NSObject {

    fileprivate let jsContext: JSContext
    internal let globalScope: ServiceWorkerGlobalScope
    let dispatchQueue = DispatchQueue.global(qos: .background)

    fileprivate static var virtualMachine = JSVirtualMachine()!
    
    static var allJSContexts = NSHashTable<JSContext>.weakObjects()

    @objc public init(_ worker: ServiceWorker) throws {

        self.jsContext = JSContext(virtualMachine: ServiceWorkerExecutionEnvironment.virtualMachine)
        
        // We use this in tests to ensure all JSContexts get cleared up. Should put behind a debug flag.
        ServiceWorkerExecutionEnvironment.allJSContexts.add(self.jsContext)
    
        self.globalScope = try ServiceWorkerGlobalScope(context: self.jsContext, worker)

        super.init()
        self.jsContext.exceptionHandler = { [unowned self] (_: JSContext?, error: JSValue?) in
            // Thrown errors don't error on the evaluateScript call (necessarily?), so after
            // evaluating, we need to check whether there is a new exception.
            // unowned is *required* to avoid circular references that mean this never gets garbage
            // collected
            self.currentException = error
        }

        // add setTimeout etc to our context
        _ = TimeoutManager(for: self, with: self.jsContext)
    }

    deinit {
        NSLog("Deinit execution environment: Garbage collect.")
        self.currentException = nil
        self.globalScope.shutdown()
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
