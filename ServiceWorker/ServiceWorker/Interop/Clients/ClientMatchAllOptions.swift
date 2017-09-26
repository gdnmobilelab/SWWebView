import Foundation

@objc public class ClientMatchAllOptions: NSObject {
    let includeUncontrolled: Bool
    let type: String

    init(includeUncontrolled: Bool, type: String) {
        self.includeUncontrolled = includeUncontrolled
        self.type = type
    }
}
