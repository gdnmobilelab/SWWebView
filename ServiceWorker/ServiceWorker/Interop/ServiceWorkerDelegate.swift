//
//  ServiceWorkerDelegate.swift
//  ServiceWorker
//
//  Created by alastair.coote on 30/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public protocol ServiceWorkerDelegate {
    
    var storageURL: URL { get }
 
    @objc optional func getRegistration(for: ServiceWorker) -> ServiceWorkerRegistrationProtocol
    @objc optional func importScripts(at: [URL], for:ServiceWorker, _ callback: @escaping (_: Error?, _: [String]?) -> Void)
    
}
