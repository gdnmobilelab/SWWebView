//
//  MessagePortHandler.swift
//  SWWebView
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer
import ServiceWorker
import PromiseKit

class MessagePortHandler {

    class SerializedMessagePortMessage: ToJSON {
        let forID: String
        let message: Any

        init(forID: String, message: Any) {
            self.forID = forID
            self.message = message
        }

        func toJSONSuitableObject() -> Any {
            return [
                "id": self.forID,
                "message": self.message
            ]
        }
    }

    class SavedPort: NSObject, MessagePortTarget {
        let id: String
        let eventStream: EventStream
        weak var port: SWMessagePort?

        let started = true

        func start() {
            // We don't implement this.
        }

        func close() {
            NSLog("close?")
        }

        init(_ port: SWMessagePort, in eventStream: EventStream) {
            self.id = UUID().uuidString
            self.eventStream = eventStream
            super.init()
            port.targetPort = self
            port.start()
            self.port = port
        }

        func receiveMessage(_ evt: ExtendableMessageEvent) {
            let message = SerializedMessagePortMessage(forID: self.id, message: evt.data)
            self.eventStream.sendUpdate(identifier: "messageportmessage", object: message)
        }
    }

    static var savedPorts: [SavedPort] = []

    static func makeMessagePort(eventStream: EventStream, json _: AnyObject?) throws -> Promise<Any?> {

        let port = SWMessagePort()
        let savedPort = SavedPort(port, in: eventStream)
        self.savedPorts.append(savedPort)

        return Promise(value: [
            "id": savedPort.id
        ])
    }

    static func proxyMessage(eventStream: EventStream, json: AnyObject?) throws -> Promise<Any?> {

        return firstly { () -> Promise<Any?> in

            guard let portID = json?["id"] as? String else {
                throw ErrorMessage("No MessagePort ID provided")
            }

            guard let message = json?["message"] as AnyObject? else {
                throw ErrorMessage("No message provided")
            }

            guard let savedPort = self.savedPorts.first(where: { $0.eventStream == eventStream && $0.id == portID }) else {
                throw ErrorMessage("No MessagePort with this ID")
            }

            savedPort.port?.postMessage(message)

            return Promise(value: nil)
        }
    }

    static func map(transferables: [AnyObject], in container: ServiceWorkerContainer) throws -> [SWMessagePort] {

        return try transferables.map { item in

            guard let serializedInfo = item["__hybridSerialized"] as? [String: AnyObject] else {
                throw ErrorMessage("This does not appear to be a serialized object")
            }

            if serializedInfo["type"] as? String != "MessagePort" {
                throw ErrorMessage("Only support MessagePort transfers right now")
            }

            guard let portID = serializedInfo["id"] as? String else {
                throw ErrorMessage("Did not provide a MessagePort ID")
            }

            guard let existing = self.savedPorts.first(where: { $0.eventStream.container == container && $0.id == portID })?.port else {
                throw ErrorMessage("The specified port does not exist")
            }

            return existing
        }
    }
}
