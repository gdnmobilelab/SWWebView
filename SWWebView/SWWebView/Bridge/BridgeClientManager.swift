//
//  BridgeClientManager.swift
//  SWWebView
//
//  Created by alastair.coote on 28/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

public class BridgeClientManager: WorkerClientsProtocol {
    
    public init() {
        
    }
    
    public func get(id: String, worker: ServiceWorker, _ cb: (Error?, ClientProtocol?) -> Void) {
        
    }
    
    public func matchAll(options: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void) {
        
    }
    
    public func openWindow(_: URL, _ cb: (Error?, ClientProtocol?) -> Void) {
        
    }
    
    public func claim(_ cb: (Error?) -> Void) {
        
    }
    
    
}
