import Foundation
import JavaScriptCore

@objc public protocol MessageEventExports: EventExports, JSExport {
    var data: Any { get }
    var ports: [SWMessagePort] { get }
}

@objc public class ExtendableMessageEvent: ExtendableEvent, MessageEventExports {
    public let data: Any
    public let ports: [SWMessagePort]

    public init(data: Any, ports: [SWMessagePort] = []) {
        self.data = data
        self.ports = ports
        super.init(type: "message")
    }

    public required init(type _: String) {
        fatalError("MessageEvent must be initialized with data")
    }
}
