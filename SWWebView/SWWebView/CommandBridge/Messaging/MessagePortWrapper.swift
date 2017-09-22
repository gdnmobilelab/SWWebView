//
//  MessagePortWrapper.swift
//  SWWebView
//
//  Created by alastair.coote on 20/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

class MessagePortWrapper: NSObject, MessagePortTarget {

    // We keep a reference to this because the MessagePort itself only
    // has a weak reference to this as its target. We keep a strong
    // reference until the port has been closed, at which point we remove it.
    static var activePorts = Set<MessagePortWrapper>()

    let id: String
    let eventStream: EventStream
    weak var port: SWMessagePort?

    let started = true

    func start() {
        // We don't implement this.
    }

    func close() {
        MessagePortWrapper.activePorts.remove(self)
        let close = MessagePortAction(type: .close, id: self.id, data: nil)
        self.eventStream.sendUpdate(identifier: "messageport", object: close)
        NSLog("close?")
    }

    init(_ port: SWMessagePort, in eventStream: EventStream) {
        self.id = UUID().uuidString
        self.eventStream = eventStream
        super.init()
        port.targetPort = self
        port.start()
        self.port = port
        MessagePortWrapper.activePorts.insert(self)
    }

    func receiveMessage(_ evt: ExtendableMessageEvent) {
        
        // A MessagePort message can, in turn, send its own ports. If that's happened
        // we need to create new wrappers for these ports too.
        
        let wrappedPorts = evt.ports.map { MessagePortWrapper($0, in: self.eventStream).id }

        let message = MessagePortAction(type: .message, id: self.id, data: evt.data, portIds: wrappedPorts)

        self.eventStream.sendUpdate(identifier: "messageport", object: message)
    }
}
