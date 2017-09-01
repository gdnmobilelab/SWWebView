//
//  ServiceWorkerRegistrationProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol ServiceWorkerRegistrationProtocol {
    func showNotification(_: JSValue) -> JSValue
    var id: String { get }
    var scope:URL {get}
    var active:ServiceWorker? {get}
    var waiting:ServiceWorker? {get}
    var installing:ServiceWorker? {get}
    var redundant:ServiceWorker? {get}
}
