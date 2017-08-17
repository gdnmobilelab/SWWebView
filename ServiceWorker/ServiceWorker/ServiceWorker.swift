//
//  ServiceWorker.swift
//  ServiceWorker
//
//  Created by alastair.coote on 14/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc public class ServiceWorker: NSObject {

    public let url: URL
    public let id: String
    let registration: ServiceWorkerRegistrationProtocol
    let loadContent: (ServiceWorker) -> String
    
    public static var storageURL:URL? = nil

    fileprivate var _installState:ServiceWorkerInstallState
    
    public var state: ServiceWorkerInstallState {
        get {
            return self._installState
        }
        set(value) {
            self._installState = value
            GlobalEventLog.notifyChange(self)
        }
    }

    public init(id: String, url: URL, registration: ServiceWorkerRegistrationProtocol, state: ServiceWorkerInstallState, loadContent: @escaping (ServiceWorker) -> String) {
        self.id = id
        self.url = url
        self.registration = registration
        self.loadContent = loadContent
        self._installState = state
        super.init()
    }

    deinit {
        NSLog("deinit worker")
    }

    @objc public init(id: String, url: URL, registration: ServiceWorkerRegistrationProtocol, state: ServiceWorkerInstallState, content: String) {
        self.id = id
        self.url = url
        self.registration = registration
        self.loadContent = { _ in
            content
        }
        self._installState = state
        super.init()
    }

    fileprivate var isDestroyed = false
    @objc public func destroy() {
        self.isDestroyed = true
    }

    fileprivate var _executionEnvironment: ServiceWorkerExecutionEnvironment?

    internal func getExecutionEnvironment() -> Promise<ServiceWorkerExecutionEnvironment> {

        if self._executionEnvironment != nil {
            return Promise(value: self._executionEnvironment!)
        }

        if self.isDestroyed {
            return Promise(error: ErrorMessage("Worker has been destroyed"))
        }

        // Being lazy means that we can create instances of ServiceWorker whenever we feel
        // like it (like, say, when ServiceWorkerRegistration is populating active, waiting etc)
        // without incurring a huge penalty for doing so.

        Log.info?("Creating execution environment for worker: " + self.id)

        return firstly {
            let env = try ServiceWorkerExecutionEnvironment(self)
            let script = loadContent(self)
            return env.evaluateScript(script, withSourceURL: self.url)
                .then { _ -> ServiceWorkerExecutionEnvironment in
                    // return value doesn't really mean anything here
                    self._executionEnvironment = env
                    return env
            }
        }
        
    }

    public func evaluateScript(_ script: String) -> Promise<JSValue?> {

        return self.getExecutionEnvironment()
            .then { exec in
                exec.evaluateScript(script)
            }
    }

    public func withJSContext(_ cb: @escaping (JSContext) throws -> Void) -> Promise<Void> {
        return self.getExecutionEnvironment()
            .then { exec -> Promise<Void> in
                exec.withJSContext(cb)
            }
    }

    @objc func evaluateScript(_ script: String, callback: @escaping (Error?, JSValue?) -> Void) {
        self.evaluateScript(script)
            .then { val in
                callback(nil, val)
            }
            .catch { err in
                callback(err, nil)
            }
    }

    public func dispatchEvent(_ event: Event) -> Promise<Void> {

        return self.getExecutionEnvironment()
            .then { exec -> Void in
                if exec.currentException != nil {
                    throw ErrorMessage("Cannot dispatch event: context is in error state")
                }
                exec.globalScope.dispatchEvent(event)
            }
    }

    public var skipWaitingStatus: Bool {
        if self._executionEnvironment == nil {
            return false
        } else {
            return self._executionEnvironment!.globalScope.skipWaitingStatus
        }
    }

    /// The Service Worker API requires that we cache imported scripts as part of the loading
    /// process. But because we want this implementation to be self-contained, we provide this
    /// hook for another module (i.e. ServiceWorkerContainer) to actually implement importing.
    public var importScripts: (ServiceWorker, [URL]) throws -> [String] = ServiceWorker.importScriptsDefault

    fileprivate static func importScriptsDefault(worker _: ServiceWorker, scripts _: [URL]) throws -> [String] {
        throw ErrorMessage("You must provide an importScripts implementation on ServiceWorker")
    }
}
