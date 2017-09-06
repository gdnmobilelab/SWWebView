//
//  ServiceWorkerContainer.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import ServiceWorker

@objc public class ServiceWorkerContainer: NSObject, WindowClientProtocol {

    public var id: String

    public var url: URL

    public let origin: URL
    public var readyRegistration: ServiceWorkerRegistrationProtocol?
    //    fileprivate var _ready: Promise<ServiceWorkerRegistration>?
    //    fileprivate var _readyFulfill: ((ServiceWorkerRegistration) -> Void)?
    fileprivate var registrationChangeListener: Listener<ServiceWorkerRegistration>?
    fileprivate var workerChangeListener: Listener<ServiceWorker>?

    let registrationFactory: WorkerRegistrationFactory

    public var controller: ServiceWorker?

    //    fileprivate var _pendingReadyPromise: Promise<ServiceWorkerRegistration>? = nil
    //    fileprivate var _pendingReadyFulfill: ((ServiceWorkerRegistration) -> Void)? = nil
    //
    //    public var ready: Promise<ServiceWorkerRegistration> {
    //        get {
    //            return self._pendingReadyPromise
    //        }
    //    }

    public func claim(by worker: ServiceWorker) {
        self.controller = worker
        self.readyRegistration = worker.registration
        GlobalEventLog.notifyChange(self)
    }

    func resetReadyRegistration() throws {
        /// ServiceWorkerContainer.ready is a promise that resolves when a registration
        /// under the scope of the container has an active worker. It's quite possible that
        /// there will already be an active worker when the container is created, so we check
        /// for that.
        self.readyRegistration = try self.registrationFactory.getReadyRegistration(for: self.url)

        if self.readyRegistration != nil {
            self.controller = self.readyRegistration?.active
            //            self._ready = Promise(value: self.readyRegistration!)
        } else {
            self.controller = nil
            //            self._ready = Promise { fulfill, _ in
            //                self._readyFulfill = fulfill
            //            }
            //            .then { reg -> ServiceWorkerRegistration in
            //                GlobalEventLog.notifyChange(self)
            //                return reg
            //            }
        }
    }

    public init(forURL: URL, withFactory: WorkerRegistrationFactory) throws {
        self.url = forURL
        self.id = UUID().uuidString

        guard var components = URLComponents(url: forURL, resolvingAgainstBaseURL: true) else {
            throw ErrorMessage("Could not parse container URL")
        }
        components.path = "/"
        components.queryItems = nil

        guard let origin = components.url else {
            throw ErrorMessage("Could not create container URL")
        }
        self.origin = origin

        self.registrationFactory = withFactory

        super.init()
        try self.resetReadyRegistration()
    }

    fileprivate var defaultScope: URL {
        if self.url.absoluteString.hasSuffix("/") == false {
            return self.url.deletingLastPathComponent()
        } else {
            return self.url
        }
    }

    fileprivate func getRegistrationsSync() throws -> [ServiceWorkerRegistration] {
        return try CoreDatabase.inConnection { db in

            guard var components = URLComponents(url: self.url, resolvingAgainstBaseURL: true) else {
                throw ErrorMessage("Could not create URL components from registration URL")
            }
            components.path = "/"

            guard let rootURL = components.url else {
                throw ErrorMessage("Could not create root URL for container")
            }

            let like = rootURL.absoluteString + "%"

            return try db.select(sql: "SELECT registration_id FROM registrations WHERE scope LIKE ?", values: [like] as [Any]) { resultSet -> [ServiceWorkerRegistration] in

                var ids: [String] = []

                while try resultSet.next() {

                    guard let regID = try resultSet.string("registration_id") else {
                        throw ErrorMessage("Found a registration with no ID")
                    }

                    ids.append(regID)
                }

                return try ids.map { id in
                    guard let reg = try self.registrationFactory.get(byId: id) else {
                        throw ErrorMessage("Could not create registration that exists in database")
                    }
                    return reg
                }
            }
        }
    }

    public func getRegistrations() -> Promise<[ServiceWorkerRegistration]> {
        return firstly {
            Promise(value: try self.getRegistrationsSync())
        }
    }

    public func getRegistration(_ scope: URL? = nil) -> Promise<ServiceWorkerRegistration?> {

        let scopeToCheck = scope ?? self.url

        return CoreDatabase.inConnection { db in

            try db.select(sql: """
                SELECT registration_id
                FROM registrations WHERE ? LIKE (scope || '%')
                ORDER BY length(scope) DESC
                LIMIT 1
            """, values: [scopeToCheck.absoluteString]) { resultSet -> Promise<String?> in
                if try resultSet.next() == false {
                    return Promise(value: nil)
                }
                guard let id = try resultSet.string("registration_id") else {
                    throw ErrorMessage("Registration in database has no ID")
                }
                return Promise(value: id)
            }
        }
        .then { regId -> ServiceWorkerRegistration? in

            guard let reg = regId else {
                return nil
            }

            return try self.registrationFactory.get(byId: reg)
        }
    }

    public func register(workerURL: URL, options: ServiceWorkerRegistrationOptions?) -> Promise<ServiceWorkerRegistration> {

        return firstly {

            if workerURL.host != url.host {
                throw ErrorMessage("Service worker scope must be on the same domain as both the page and worker URL")
            }

            // let's say, workerURL = "/test/worker.js?thing=this"
            guard var scopeComponents = URLComponents(url: workerURL, resolvingAgainstBaseURL: true) else {
                throw ErrorMessage("Could not parse worker URL")
            }

            // strip our querystring items, so it's now "/test/worker.js"
            scopeComponents.queryItems = nil

            if workerURL.path.last != "/" {
                // if our worker URL is a file (and it usually is) strip that out.
                // so, scopeURL is now "/test/". For some reason this strips out the "/"
                // at the end of the path, so we need to add it back in.
                scopeComponents.path = workerURL.deletingLastPathComponent().path + "/"
            }

            guard var scopeURL = scopeComponents.url else {
                throw ErrorMessage("Could not parse out default scope URL from worker URL")
            }

            // A register command can provide a custom scope. BUT it cannot exceed our current scope
            // so we keep a reference to the originally calculated value.
            // So, maxScope = "/test/"
            let maxScope = scopeURL

            if let scope = options?.scope {

                // We have a custom scope. Let's say, "/test/sub-test/". That scope must
                // fall under our maximum scope.
                if scope.absoluteString.hasPrefix(maxScope.absoluteString) == false {
                    throw ErrorMessage("Service worker must exist under the scope it is being registered to")
                }
                scopeURL = scope
            }

            if workerURL.absoluteString.starts(with: maxScope.absoluteString) == false {
                throw ErrorMessage("Script must be within scope")
            }

            let existingRegistration = try self.registrationFactory.get(byScope: scopeURL)

            let reg = try existingRegistration ?? self.registrationFactory.create(scope: scopeURL)

            return reg.register(workerURL)
                .then { result -> ServiceWorkerRegistration in

                    result.registerComplete
                        .then { () -> Void in
                            // If our registration was successful and this container is within
                            // its scope, we should set it as the ready registration

                            if self.url.absoluteString.hasPrefix(reg.scope.absoluteString) {
                                self.readyRegistration = reg
                                GlobalEventLog.notifyChange(self)
                            }
                        }
                        .catch { error in
                            GlobalEventLog.notifyChange(WorkerInstallationError(worker: result.worker, container: self, error: error))
                        }

                    return reg
                }
        }
    }

    public weak var windowClientDelegate: WindowClientProtocol?

    public func focus(_ cb: (Error?, WindowClientProtocol?) -> Void) {
        if let delegate = self.windowClientDelegate {
            delegate.focus(cb)
        } else {
            cb(ErrorMessage("Container has no windowClientDelegate"), nil)
        }
    }

    public func navigate(to: URL, _ cb: (Error?, WindowClientProtocol?) -> Void) {
        if let delegate = self.windowClientDelegate {
            delegate.navigate(to: to, cb)
        } else {
            cb(ErrorMessage("Container has no windowClientDelegate"), nil)
        }
    }

    public var focused: Bool {
        if let delegate = self.windowClientDelegate {
            return delegate.focused
        } else {
            Log.error?("Tried to fetch focused state of ServiceWorkerContainer when no windowClientDelegate is set")
            return false
        }
    }

    public var visibilityState: WindowClientVisibilityState {
        if let delegate = self.windowClientDelegate {
            return delegate.visibilityState
        } else {
            Log.error?("Tried to fetch visibility state of ServiceWorkerContainer when no windowClientDelegate is set")
            return WindowClientVisibilityState.Hidden
        }
    }

    public func postMessage(message: Any?, transferable: [Any]?) {
        if let delegate = self.windowClientDelegate {
            return delegate.postMessage(message: message, transferable: transferable)
        } else {
            Log.error?("Tried to postMessage to ServiceWorkerContainer when no windowClientDelegate is set")
        }
    }

    public var type: ClientType {
        if let delegate = self.windowClientDelegate {
            return delegate.type
        } else {
            Log.error?("Tried to fetch ClientType of ServiceWorkerContainer when no windowClientDelegate is set")
            return ClientType.Window
        }
    }
}
