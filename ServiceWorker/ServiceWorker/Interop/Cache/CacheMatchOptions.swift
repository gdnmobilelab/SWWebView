//
//  CacheMatchOptions.swift
//  ServiceWorker
//
//  Created by alastair.coote on 22/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

public struct CacheMatchOptions {
    let ignoreSearch: Bool
    let ignoreMethod: Bool
    let ignoreVary: Bool
    let cacheName: String?
}

public extension CacheMatchOptions {
    static func fromDictionary(opts: [String: Any]) -> CacheMatchOptions {

        let ignoreSearch = opts["ignoreSearch"] as? Bool ?? false
        let ignoreMethod = opts["ignoreMethod"] as? Bool ?? false
        let ignoreVary = opts["ignoreVary"] as? Bool ?? false
        let cacheName: String? = opts["cacheName"] as? String

        return CacheMatchOptions(ignoreSearch: ignoreSearch, ignoreMethod: ignoreMethod, ignoreVary: ignoreVary, cacheName: cacheName)
    }
}
