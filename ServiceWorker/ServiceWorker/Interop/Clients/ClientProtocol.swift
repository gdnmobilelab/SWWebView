//
//  ClientProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 23/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol ClientProtocol {
    func postMessage(message: Any?, transferable: [Any]?) -> Void
    var id: String { get }
    var type: ClientType { get }
    var url: URL { get }
}
