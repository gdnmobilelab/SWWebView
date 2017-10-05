import Foundation
import JavaScriptCore

@objc public protocol MessageChannelExports: JSExport {
    var port1: SWMessagePort { get }
    var port2: SWMessagePort { get }
    init()
}

/// An implementation of the JavaScript MessageChannel object:
/// https://developer.mozilla.org/en-US/docs/Web/API/MessageChannel
/// This is basically just a pair of MessagePorts, connected to each other.
@objc public class MessageChannel: NSObject, MessageChannelExports {
    public let port1: SWMessagePort
    public let port2: SWMessagePort

    public required override init() {
        self.port1 = SWMessagePort()
        self.port2 = SWMessagePort()
        super.init()
        self.port1.targetPort = port2
        self.port2.targetPort = self.port1
    }
}
