import Foundation

@objc public protocol CacheStorageProviderDelegate {
    @objc func createCacheStorage(_: ServiceWorker) throws -> CacheStorage
}
