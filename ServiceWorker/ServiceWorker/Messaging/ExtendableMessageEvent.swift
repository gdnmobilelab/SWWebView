import Foundation
import JavaScriptCore

@objc public protocol MessageEventExports: Event, JSExport {
    var data: Any { get }
    var ports: [SWMessagePort] { get }
}

@objc public class ExtendableMessageEvent: ExtendableEvent, MessageEventExports {
    public let data: Any
    public let ports: [SWMessagePort]
    //    public let type: String

    public init(data: Any, ports: [SWMessagePort] = []) {
        self.data = data
        //        self.type = "message"
        self.ports = ports
        super.init(type: "message")
    }
}
