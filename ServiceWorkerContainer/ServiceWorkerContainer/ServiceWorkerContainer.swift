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

@objc public class ServiceWorkerContainer: NSObject {

    public let containerURL: URL
    public let origin: URL
    public var readyRegistration:ServiceWorkerRegistration?
    fileprivate var _ready:Promise<ServiceWorkerRegistration>? = nil
    fileprivate var _readyFulfill: ((ServiceWorkerRegistration) -> Void)? = nil
    fileprivate var registrationChangeListener: Listener<ServiceWorkerRegistration>? = nil
    fileprivate var workerChangeListener: Listener<ServiceWorker>? = nil
    
    public var controller: ServiceWorker?
    
    public var ready: Promise<ServiceWorkerRegistration> {
        get {
            return self._ready!
        }
    }
    
    func resetReadyRegistration() throws {
        /// ServiceWorkerContainer.ready is a promise that resolves when a registration
        /// under the scope of the container has an active worker. It's quite possible that
        /// there will already be an active worker when the container is created, so we check
        /// for that.
        self.readyRegistration = try ServiceWorkerRegistration.getReadyRegistration(for: self.containerURL)
        
        if self.readyRegistration != nil {
            self.controller = self.readyRegistration?.active
            self._ready = Promise(value: self.readyRegistration!)
        } else {
            self.controller = nil
            self._ready = Promise { fulfill, reject in
                self._readyFulfill = fulfill
            }
        }
    }

    public init(forURL: URL) throws {
        self.containerURL = forURL
        
        var components = URLComponents(url: forURL, resolvingAgainstBaseURL: true)!
        components.path = "/"
        components.queryItems = nil
        self.origin = components.url!
        
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
            
            if self.containerURL.absoluteString.hasPrefix(reg.scope.absoluteString) == false {
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

    // We don't ever want to have more than one container for a URL, so we keep this weak map internally,
    // then, when running get(), we return an existing instance if it exists.
//    fileprivate static let activeContainers = NSHashTable<ServiceWorkerContainer>.weakObjects()
//
//    public static func get(for url: URL) throws -> ServiceWorkerContainer {
//        
//        let existing = self.activeContainers.allObjects.first { $0.containerURL.absoluteString == url.absoluteString }
//        if existing != nil {
//            return existing!
//        } else {
//            let newContainer = try ServiceWorkerContainer(forURL: url)
//            self.activeContainers.add(newContainer)
//            return newContainer
//        }
//    }

    fileprivate var defaultScope: URL {
        if self.containerURL.absoluteString.hasSuffix("/") == false {
            return self.containerURL.deletingLastPathComponent()
        } else {
            return self.containerURL
        }
    }
    
    
   
    
    
    fileprivate func getRegistrationsSync() throws -> [ServiceWorkerRegistration] {
        return try CoreDatabase.inConnection { db in
            
            var components = URLComponents(url: self.containerURL, resolvingAgainstBaseURL: true)!
            components.path = "/"
            
            let like = components.url!.absoluteString + "%"
            
            return try db.select(sql: "SELECT scope FROM registrations WHERE scope LIKE ?", values: [like] as [Any]) { resultSet -> [ServiceWorkerRegistration] in
                
                var scopes: [URL] = []
                
                while resultSet.next() {
                    scopes.append(try resultSet.url("scope")!)
                }
                
                return try scopes.map { scope in
                    return try ServiceWorkerRegistration.get(byScope: scope)!
                }
                    
            }
        }
    }

    public func getRegistrations() -> Promise<[ServiceWorkerRegistration]> {
        return firstly {
            return Promise(value: try self.getRegistrationsSync())
        }
    }

    public func getRegistration(_ scope: URL? = nil) -> Promise<ServiceWorkerRegistration?> {

        let scopeToCheck = scope ?? self.containerURL

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
                return Promise(value: try resultSet.string("registration_id")!)
            }
        }
        .then { regId -> ServiceWorkerRegistration? in
            if regId == nil {
                return nil
            }
            return try ServiceWorkerRegistration.get(byId: regId!)
        }
    }

    public func register(workerURL: URL, options: ServiceWorkerRegistrationOptions?) -> Promise<ServiceWorkerRegistration> {
        
        return firstly {
            var scopeURL = workerURL

            if workerURL.host != containerURL.host {
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

            let registration = try ServiceWorkerRegistration.getOrCreate(byScope: scopeURL)
            return registration.register(workerURL)
                .then { (worker, installationPromise) -> ServiceWorkerRegistration in
                    
                    installationPromise
                        .catch { error in
                            GlobalEventLog.notifyChange(WorkerInstallationError(worker: worker, container: self, error: error))
                    }
                    
                    return registration
                }
        }
    }
}
