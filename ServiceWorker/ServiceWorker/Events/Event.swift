import Foundation
import JavaScriptCore

@objc public protocol EventExports: JSExport {
    var type: String { get }
    init(type: String)
}

@objc open class Event: NSObject, EventExports {
    public let type: String

    public required init(type: String) {
        self.type = type
    }
}
