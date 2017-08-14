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

public class ServiceWorkerContainer : Hashable {
   
    public static func ==(lhs: ServiceWorkerContainer, rhs: ServiceWorkerContainer) -> Bool {
        return lhs.hashValue != rhs.hashValue
    }
    
    public var hashValue: Int {
        get {
            return self.containerURL.absoluteString.hashValue
        }
    }

    public let containerURL: URL

    init(forURL: URL) {
        self.containerURL = forURL
    }
    
    // We don't ever want to have more than one container for a URL, so we keep this weak map internally,
    // then, when running get(), we return an existing instance if it exists.
    fileprivate static let activeContainers = NSHashTable<ServiceWorkerContainer>.weakObjects()
    
    public static func get(for url: URL) -> ServiceWorkerContainer {
        
        let existing = self.activeContainers.allObjects.first { $0.containerURL.absoluteString == url.absoluteString}
        if existing != nil {
            return existing!
        } else {
            let newContainer = ServiceWorkerContainer(forURL: url)
            self.activeContainers.add(newContainer)
            return newContainer
        }
    }
    
    public func getRegistrations() -> Promise<[ServiceWorkerRegistration]> {
        return CoreDatabase.inConnection { db in
            
            return try db.select(sql: "SELECT scope FROM registrations WHERE scope LIKE ?", values: [self.containerURL.absoluteString + "%"] as [Any]) { resultSet -> Promise<[URL]> in
                
                var scopes: [URL] = []
                
                while resultSet.next() {
                    scopes.append(try resultSet.url("scope")!)
                }
                
                return Promise(value: scopes)
                
            }
                .then { scopes in
                    return try scopes.map { scope in
                        return try ServiceWorkerRegistration.get(scope: scope)!
                    }
            }
            
            
        }
    }
    
    public func getRegistration() -> Promise<ServiceWorkerRegistration?> {
        return self.getRegistrations()
            .then { registrations in
                return registrations.sorted(by: { (one, two) -> Bool in
                    return one.scope.absoluteString.count > two.scope.absoluteString.count
                }).first
                
        }
    }


    public func register(workerURL: URL, options: ServiceWorkerRegistrationOptions?) -> Promise<ServiceWorkerRegistration> {

        return firstly {
            var scopeURL = containerURL
            
            if scopeURL.absoluteString.last! != "/" {
                // if we are a a file (.e.g. /test.html) the scope, by default, is "/")
                scopeURL.deleteLastPathComponent()
            }
            
            if let scope = options?.scope {
                // By default we register to the current URL, but we can specify
                // another scope.
                if scopeURL.host != containerURL.host || workerURL.host != containerURL.host {
                    throw ErrorMessage("Service worker scope must be on the same domain as both the page and worker URL")
                }
                if workerURL.absoluteString.hasPrefix(scopeURL.absoluteString) == false {
                    throw ErrorMessage("Service worker must exist under the scope it is being registered to")
                }
                scopeURL = scope
            }

            if workerURL.absoluteString.starts(with: scopeURL.absoluteString) == false {
                throw ErrorMessage("Script must be within scope")
            }

            var registration = try ServiceWorkerRegistration.get(scope: scopeURL)
            if registration == nil {
                registration = try ServiceWorkerRegistration.create(scope: scopeURL)
            }
            return registration!.register(workerURL)
                .then {
                    registration!
                }
        }
    }
}
