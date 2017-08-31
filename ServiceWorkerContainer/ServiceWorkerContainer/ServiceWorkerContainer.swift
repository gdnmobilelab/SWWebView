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
    public var readyRegistration: ServiceWorkerRegistration?
    fileprivate var _ready: Promise<ServiceWorkerRegistration>?
    fileprivate var _readyFulfill: ((ServiceWorkerRegistration) -> Void)?
    fileprivate var registrationChangeListener: Listener<ServiceWorkerRegistration>?
    fileprivate var workerChangeListener: Listener<ServiceWorker>?

    let registrationFactory: WorkerRegistrationFactory

    public var controller: ServiceWorker?

    public var ready: Promise<ServiceWorkerRegistration> {
        return self._ready!
    }

    func resetReadyRegistration() throws {
        /// ServiceWorkerContainer.ready is a promise that resolves when a registration
        /// under the scope of the container has an active worker. It's quite possible that
        /// there will already be an active worker when the container is created, so we check
        /// for that.
        self.readyRegistration = try self.registrationFactory.getReadyRegistration(for: self.url)

        if self.readyRegistration != nil {
            self.controller = self.readyRegistration?.active
            self._ready = Promise(value: self.readyRegistration!)
        } else {
            self.controller = nil
            self._ready = Promise { fulfill, _ in
                self._readyFulfill = fulfill
            }
        }
    }

    public init(forURL: URL, withFactory: WorkerRegistrationFactory) throws {
        self.url = forURL
        self.id = UUID().uuidString

        var components = URLComponents(url: forURL, resolvingAgainstBaseURL: true)!
        components.path = "/"
        components.queryItems = nil
        self.origin = components.url!

        self.registrationFactory = withFactory

        super.init()
        try self.resetReadyRegistration()

        // No matter if we have an active registration already, we need to listen if a new
        // one comes along - if its scope is more specific than our currently active one,
        // we need to replace it.
        self.registrationChangeListener = GlobalEventLog.addListener { [unowned self] (reg: ServiceWorkerRegistration) in

            if reg.unregistered == true && reg == self.readyRegistration {
                // if this is already our active registration, the only thing we
                // care about is if it has become unregistered.

                do {
                    try self.resetReadyRegistration()
                } catch {
                    Log.error?("Unable to reset ready registration: \(error)")
                }

                GlobalEventLog.notifyChange(self)

                return
            } else if reg == self.readyRegistration || reg.unregistered == true || reg.active == nil {
                return
            }

            if self.url.absoluteString.hasPrefix(reg.scope.absoluteString) == false {
                // not in scope, disregard
                return
            }

            if self.readyRegistration != nil && reg.scope.absoluteString.count <= self.readyRegistration!.scope.absoluteString.count {
                NSLog("Scope of \(reg.scope.absoluteString) does not replace \(self.readyRegistration!.scope.absoluteString)")
                // scope is less specific than the one we currently have, disregard
                return
            }

            self.readyRegistration = reg
            if let fulfill = self._readyFulfill {
                fulfill(self.readyRegistration!)
                self._readyFulfill = nil
            }
            self._ready = Promise(value: reg)

            GlobalEventLog.notifyChange(self)
        }

        //        self.workerChangeListener = GlobalEventLog.addListener { [unowned self] (worker:ServiceWorker) in
        //            if self.readyRegistration?.active == worker && worker.state == .activated {
        //                self.controller = worker
        //                GlobalEventLog.notifyChange(self)
        //            } else if self.controller == worker && worker.state == .redundant {
        //                self.controller = nil
        //                GlobalEventLog.notifyChange(self)
        //            }
        //        }
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

            let like = components.url!.absoluteString + "%"

            return try db.select(sql: "SELECT registration_id FROM registrations WHERE scope LIKE ?", values: [like] as [Any]) { resultSet -> [ServiceWorkerRegistration] in

                var ids: [String] = []

                while resultSet.next() {
                    ids.append(try resultSet.string("registration_id")!)
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
                if resultSet.next() == false {
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
            var scopeURL = workerURL

            if workerURL.host != url.host {
                throw ErrorMessage("Service worker scope must be on the same domain as both the page and worker URL")
            }

            if scopeURL.absoluteString.last! != "/" {
                // if we are a a file (.e.g. /test.html) the scope, by default, is "/")
                scopeURL.deleteLastPathComponent()
            }

            // The maximum scope is set no matter what custom scope is or is not provided.
            let maxScope = scopeURL

            if let scope = options?.scope {

                // By default we register to the current URL, but we can specify
                // another scope.
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
                        .catch { error in
                            GlobalEventLog.notifyChange(WorkerInstallationError(worker: result.worker, container: self, error: error))
                        }

                    return reg
                }
        }
    }

    public var windowClientDelegate: WindowClientProtocol?

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
