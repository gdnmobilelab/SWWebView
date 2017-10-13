import Foundation

@objc public protocol CacheStorageProviderDelegate {

    /// CacheStorage instances are specific to origin, but we send in the worker
    /// in case a custom implementation wants to do more.
    @objc func createCacheStorage(_: ServiceWorker) throws -> CacheStorage
}
