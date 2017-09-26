import Foundation

public struct ServiceWorkerRegistrationOptions {
    public let scope: URL?

    public init(scope: URL?) {
        self.scope = scope
    }
}
