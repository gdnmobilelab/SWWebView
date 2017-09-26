import Foundation
import JavaScriptCore

@objc public protocol MessagePortExports: JSExport {
    func postMessage(_ message: Any, _ transferList: [Transferable])
    func start()
    var onmessage: JSValue? { get set }
}

@objc public class SWMessagePort: EventTarget, Transferable, MessagePortExports, MessagePortTarget {

    fileprivate typealias QueuedMessage = (message: Any, transferList: [Transferable])

    public weak var targetPort: MessagePortTarget?
    public var started: Bool = false
    fileprivate var queuedMessages: [QueuedMessage] = []

    fileprivate var onMessageListener: SwiftEventListener<ExtendableMessageEvent>?
    fileprivate var onmessageValue: JSValue?

    public override init() {
        super.init()
        self.onMessageListener = self.addEventListener("message", { [unowned self] (event: ExtendableMessageEvent) in
            // in JS we can set onmessage directly rather than use addEventListener.
            // so we should mirror that here.
            if let onmessage = self.onmessageValue {
                onmessage.call(withArguments: [event])
            }
        })
    }

    deinit {
        if let target = self.targetPort {
            target.close()
        }
    }

    public var onmessage: JSValue? {
        get {
            return self.onmessageValue
        }
        set(value) {
            self.onmessageValue = value
            if let target = self.targetPort {
                // start is called implicitly when onmessage is set:
                // https://developer.mozilla.org/en-US/docs/Web/API/MessagePort/start
                if target.started == false {
                    target.start()
                }
            }
        }
    }

    public func start() {
        self.started = true
        self.queuedMessages.forEach { self.postMessage($0.message, $0.transferList) }
        self.queuedMessages.removeAll()
    }

    public func close() {
        self.started = false
    }

    public func postMessage(_ message: Any, _ transferList: [Transferable] = []) {

        if self.started == false {
            // MessagePorts are manually started (unless triggered by onmessage), so we need
            // to queue any pending messages before sending.
            self.queuedMessages.append((message: message, transferList: transferList))
            return
        }
        do {
            guard let targetPort = self.targetPort else {
                throw ErrorMessage("MessagePort does not have a target set")
            }

            guard let ports = transferList as? [SWMessagePort] else {
                throw ErrorMessage("All transferables must be MessagePorts for now")
            }

            let messageEvent = ExtendableMessageEvent(data: message, ports: ports)

            targetPort.receiveMessage(messageEvent)

        } catch {
            if let ctx = JSContext.current() {
                let err = JSValue(newErrorFromMessage: "\(error)", in: ctx)
                ctx.exception = err
            } else {
                Log.error?("\(error)")
            }
        }
    }

    public func receiveMessage(_ evt: ExtendableMessageEvent) {
        self.dispatchEvent(evt)
    }
}
