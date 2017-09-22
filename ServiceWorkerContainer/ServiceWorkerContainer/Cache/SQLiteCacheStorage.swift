//
//  SQLiteCacheStorage.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 22/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker
import JavaScriptCore

@objc public class SQLiteCacheStorage: NSObject, CacheStorage {

    public static var CacheClass = SQLiteCache.self as Cache.Type

    let origin: URL

    public init(for url: URL) throws {

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw ErrorMessage("Could not parse input URL")
        }
        components.path = "/"

        guard let origin = components.url else {
            throw ErrorMessage("Could not create origin URL")
        }
        self.origin = origin
        super.init()
    }

    public func match(_: JSValue, _: [String: Any]) -> JSValue {
        return JSContext.current().globalObject
    }

    public func has(_: String) -> JSValue {
        return JSContext.current().globalObject
    }

    public func open(_: String) -> JSValue {
        return JSContext.current().globalObject
    }

    public func delete(_: String) -> JSValue {
        return JSContext.current().globalObject
    }

    public func keys() -> JSValue {
        return JSContext.current().globalObject
    }
}
