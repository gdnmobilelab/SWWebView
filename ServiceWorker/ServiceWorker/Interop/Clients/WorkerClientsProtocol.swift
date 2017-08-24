//
//  WorkerClientsProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 23/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc public protocol WorkerClientsProtocol {
    func get(id:String, worker: ServiceWorker, _ cb: (Error?, ClientProtocol?) -> Void)
    func matchAll(options: ClientMatchAllOptions, _ cb: (Error?, [ClientProtocol]?) -> Void)
    func openWindow(_:URL, _ cb: (Error?,ClientProtocol?) -> Void)
    func claim(_ cb: (Error?) -> Void)
}
