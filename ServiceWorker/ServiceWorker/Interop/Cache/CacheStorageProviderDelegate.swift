//
//  CacheStorageProviderDelegate.swift
//  ServiceWorker
//
//  Created by alastair.coote on 22/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public protocol CacheStorageProviderDelegate {
    @objc func createCacheStorage(_: ServiceWorker) throws -> CacheStorage
}
