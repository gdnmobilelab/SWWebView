import Foundation
import JavaScriptCore

@objc public protocol MessageEventExports: Event, JSExport {
    var data: Any { get }
    var ports: [SWMessagePort] { get }
}

/// ExtendableMessageEvent is like an ExtendableEvent except it also lets you transfer
/// data and an array of transferrables (right now just MessagePort):
/// https://developer.mozilla.org/en-US/docs/Web/API/ExtendableMessageEvent
@objc public class ExtendableMessageEvent: ExtendableEvent, MessageEventExports {

    public let data: Any
    public let ports: [SWMessagePort]

    public init(data: Any, ports: [SWMessagePort] = []) {
        self.data = data
        self.ports = ports
        super.init(type: "message")
    }
}
