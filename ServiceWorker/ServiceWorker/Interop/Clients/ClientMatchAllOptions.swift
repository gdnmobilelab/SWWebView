import Foundation

/// Outlined here: https://developer.mozilla.org/en-US/docs/Web/API/Clients/matchAll
@objc public class ClientMatchAllOptions: NSObject {
    let includeUncontrolled: Bool
    let type: String

    init(includeUncontrolled: Bool, type: String) {
        self.includeUncontrolled = includeUncontrolled
        self.type = type
    }
}
