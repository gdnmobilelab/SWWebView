//
//  ServiceWorkerClientDelegate.swift
//  ServiceWorker
//
//  Created by alastair.coote on 31/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public protocol ServiceWorkerClientsDelegate {
    
    @objc optional func clients(_:ServiceWorker, getById: String, _ callback: (Error?, ClientProtocol?) -> Void)
    @objc optional func clients(_:ServiceWorker, matchAll: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void)
    @objc optional func clients(_:ServiceWorker, openWindow: URL, _ cb: (Error?, ClientProtocol?) -> Void)
    @objc optional func clientsClaim(_:ServiceWorker, _ cb:(Error?) -> Void)
    
}
