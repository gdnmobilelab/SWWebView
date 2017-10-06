import Foundation
import JavaScriptCore

@objc public protocol MessagePortExports: JSExport {
    func postMessage(_ message: Any, _ transferList: [Transferable])
    func start()
    var onmessage: JSValue? { get set }
}

/// An implementation of the JavaScript MessagePort class:
/// https://developer.mozilla.org/en-US/docs/Web/API/MessagePort
@objc public class SWMessagePort: EventTarget, Transferable, MessagePortExports, MessagePortTarget {

    fileprivate typealias QueuedMessage = (message: Any, transferList: [Transferable])

    public weak var targetPort: MessagePortTarget?
    public var started: Bool = false

    /// MessagePorts don't start sending messages immediately - that's done by calling start()
    /// or setting the onmessage property. Any messages sent before that are queued here.
    fileprivate var queuedMessages: [ExtendableMessageEvent] = []

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
            // If this is being removed then there's no point keeping the target open.
            // But more usefully for us, this also allows us to automatically close
            // MessagePorts that live in SWWebViews (and can't be automatically garbage
            // collected)
            target.close()
        }
    }

    public var onmessage: JSValue? {
        get {
            return self.onmessageValue
        }
        set(value) {
            self.onmessageValue = value
            // start is called implicitly when onmessage is set:
            // https://developer.mozilla.org/en-US/docs/Web/API/MessagePort/start
            self.start()
        }
    }

    public func start() {
        self.started = true
        self.queuedMessages.forEach { self.dispatchEvent($0) }
        self.queuedMessages.removeAll()
    }

    public func close() {
        self.started = false
    }

    public func postMessage(_ message: Any, _ transferList: [Transferable] = []) {

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
        if self.started == false {
            self.queuedMessages.append(evt)
        } else {
            self.dispatchEvent(evt)
        }
    }
}
