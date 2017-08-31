//
//  ServiceWorkerDelegate.swift
//  ServiceWorker
//
//  Created by alastair.coote on 30/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public protocol ServiceWorkerDelegate {

    @objc optional func serviceWorkerGetRegistration(_: ServiceWorker) -> ServiceWorkerRegistrationProtocol
    @objc optional func serviceWorker(_: ServiceWorker, importScripts: [URL], _ callback: @escaping (_: Error?, _: [String]?) -> Void)
    @objc optional func serviceWorker(_: ServiceWorker, getStoragePathForDomain: String) -> String?
}
