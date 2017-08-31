//
//  Clients.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol ClientsExports: JSExport {
    func get(_: String) -> JSValue
    func matchAll(_: [String: Any]?) -> JSValue
    func openWindow(_: String) -> JSValue
    func claim() -> JSValue
}

@objc class Clients: NSObject, ClientsExports {

    unowned let worker: ServiceWorker

    init(for worker: ServiceWorker) {
        self.worker = worker
    }

    func get(_ id: String) -> JSValue {

        let jsp = JSPromise(context: JSContext.current())
        
        if self.worker.delegate?.clients?(getById: id, for: worker, { err, clientProtocol in
            if let error = err {
                jsp.reject(error)
            } else if let clientExists = clientProtocol {
                jsp.fulfill(Client.getOrCreate(from: clientExists, in: JSContext.current()))
            } else {
                jsp.fulfill(nil)
            }
        }) == nil {
            jsp.reject(ErrorMessage("ServiceWorkerDelegate does not implement get()"))
        }
        
        return jsp.jsValue
    }

    func matchAll(_ options: [String: Any]?) -> JSValue {

        let jsp = JSPromise(context: JSContext.current())

        let type = options?["type"] as? String ?? "all"
        let includeUncontrolled = options?["includeUncontrolled"] as? Bool ?? false

        let options = ClientMatchAllOptions(includeUncontrolled: includeUncontrolled, type: type)
        
        if self.worker.delegate?.clients?(matchAll: options, for: self.worker, { err, clientProtocols in
            if let error = err {
                jsp.reject(error)
            } else {
                let mapped = clientProtocols!.map({ Client.getOrCreate(from: $0, in: JSContext.current()) })
                jsp.fulfill(mapped)
            }
        }) == nil {
            jsp.reject(ErrorMessage("ServiceWorkerDelegate does not implement matchAll()"))
        }
        
        return jsp.jsValue
    }

    func openWindow(_ url: String) -> JSValue {

        let jsp = JSPromise(context: JSContext.current())

        guard let parsedURL = URL(string: url, relativeTo: self.worker.url) else {
            jsp.reject(ErrorMessage("Could not parse URL given"))
            return jsp.jsValue
        }
        
        if self.worker.delegate?.clients?(openWindow: parsedURL, jsp.processCallback) == nil {
            jsp.reject(ErrorMessage("ServiceWorkerDelegate does not implement openWindow()"))
        }


        return jsp.jsValue
    }

    func claim() -> JSValue {

        let jsp = JSPromise(context: JSContext.current())

        if self.worker.delegate?.clients?(claimForWorker: self.worker, jsp.processCallback) == nil {
            jsp.reject(ErrorMessage("ServiceWorkerDelegate does not implement claim()"))
        }

        return jsp.jsValue
    }
}
