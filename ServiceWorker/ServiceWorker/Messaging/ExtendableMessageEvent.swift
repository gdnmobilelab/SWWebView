import Foundation
import JavaScriptCore

@objc public protocol MessageEventExports: Event, JSExport {
    var data: Any { get }
    var ports: [SWMessagePort] { get }
}

@objc public class ExtendableMessageEvent: NSObject, MessageEventExports {
    public let data: Any
    public let ports: [SWMessagePort]
    public let type: String

    public init(data: Any, ports: [SWMessagePort] = []) {
        self.data = data
        self.type = "message"
        self.ports = ports
        super.init()
    }

    public required init(type _: String) {
        fatalError("MessageEvent must be initialized with data")
    }
}
