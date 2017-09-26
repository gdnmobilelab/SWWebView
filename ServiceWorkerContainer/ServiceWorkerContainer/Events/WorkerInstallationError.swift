import Foundation
import ServiceWorker

public struct WorkerInstallationError {
    public let worker: ServiceWorker
    public let container: ServiceWorkerContainer
    public let error: Error
}
