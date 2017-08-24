//
//  EmptyWorkerClients.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public class EmptyWorkerClients : NSObject, WorkerClientsProtocol {
    
    let error = ErrorMessage("Empty stub worker client implementation")
    
    public func get(id: String, worker: ServiceWorker, _ cb: (Error?, ClientProtocol?) -> Void) {
        cb(self.error, nil)
    }
    
    public func matchAll(options: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void) {
        cb(self.error, nil)
    }
    
    public func openWindow(_: URL, _ cb: (Error?, ClientProtocol?) -> Void) {
        cb(self.error, nil)
    }
    
    public func claim(_ cb: (Error?) -> Void) {
        cb(self.error)
    }
    

    
}
