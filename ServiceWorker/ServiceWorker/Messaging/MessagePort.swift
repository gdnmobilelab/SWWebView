//
//  MessagePort.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol MessagePortExports: JSExport {
    func postMessage(_ message: Any, _ transferList: [Transferable])
    func start()
    var onmessage: JSValue? { get set }
}

@objc public class SWMessagePort: EventTarget, Transferable, MessagePortExports {

    fileprivate typealias QueuedMessage = (message: Any, transferList: [Transferable])

    public weak var targetPort: SWMessagePort?
    fileprivate var started: Bool = false
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

    public func postMessage(_ message: Any, _ transferList: [Transferable] = []) {

        if self.started == false {
            // MessagePorts are manually started (unless triggered by onmessage), so we need
            // to queue any pending messages before sending.
            self.queuedMessages.append((message: message, transferList: transferList))
            return
        }

        guard let targetPort = self.targetPort else {
            if let ctx = JSContext.current() {
                let err = JSValue(newErrorFromMessage: "MessagePort does not have a target set", in: ctx)
                ctx.exception = err
            } else {
                Log.error?("MessagePort does not have a target set")
            }
            return
        }

        let messageEvent = ExtendableMessageEvent(data: message)

        targetPort.dispatchEvent(messageEvent)
    }
}
