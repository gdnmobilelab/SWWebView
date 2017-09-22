//
//  CacheStorage.swift
//  ServiceWorker
//
//  Created by alastair.coote on 22/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol CacheStorageJSExports: JSExport {
    func match(_ request: JSValue, _ options: [String: Any]) -> JSValue
    func has(_ cacheName: String) -> JSValue
    func open(_ cacheName: String) -> JSValue
    func delete(_ cacheName: String) -> JSValue
    func keys() -> JSValue
}

@objc public protocol CacheStorage: CacheStorageJSExports, JSExport {
    static var CacheClass: Cache.Type { get }
}
