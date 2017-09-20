//
//  ServiceWorkerCommands.swift
//  SWWebView
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import ServiceWorker
import ServiceWorkerContainer

class ServiceWorkerCommands {

    fileprivate static func deserializeTransferables(message: Any, transfered: [SWMessagePort]) throws -> Any {

        if let array = message as? [Any] {
            return try array.map { try deserializeTransferables(message: $0, transfered: transfered) }
        } else if message is String || message is Int || message is Float || message is Bool {
            return message
        } else if let dict = message as? [String: Any] {

            if let transferrableIndex = (dict["__transferable"] as? [String: Int])?["index"] {
                // This is a transferred object. Replace it with the real thing.
                return transfered[transferrableIndex]
            }

            return try dict.mapValues { val in
                try deserializeTransferables(message: val, transfered: transfered)
            }

        } else {
            throw ErrorMessage("Do not know how to deserialize object \(message)")
        }
    }

    static func postMessage(eventStream: EventStream, json: AnyObject?) throws -> Promise<Any?> {

        return firstly { () -> Promise<Any?> in

            guard let workerID = json?["id"] as? String else {
                throw ErrorMessage("No worker ID was provided in the postMessage request")
            }

            guard let registrationID = json?["registrationID"] as? String else {
                throw ErrorMessage("Registration ID not provided in postMessage request")
            }

            guard let transferCount = json?["transferCount"] as? Int else {
                throw ErrorMessage("Must send a transferCount parameter, even if it is zero")
            }

            guard let message = json?["message"] as AnyObject? else {
                throw ErrorMessage("No message was provided")
            }

            // Right now we only serialize message ports so we're fine to just assume
            // every transferred object is a port
            let transferredPorts = [0 ... transferCount].map { _ in SWMessagePort() }

            // We then wrap our message ports in a wrapper that re-broadcasts received messages
            // into the page's event stream. These tidy themselves up when the native-side
            // MessagePort is discarded.
            let wrappedPorts = transferredPorts.map { MessagePortWrapper($0, in: eventStream) }

            // You can send a transferable object in your message, so now we take our
            // serialized version and inject the message ports wherever necessary.
            let deserializedMessage = try deserializeTransferables(message: message, transfered: transferredPorts)

            let worker = try eventStream.container.getWorker(byID: workerID, inRegistrationID: registrationID)

            let event = ExtendableMessageEvent(data: deserializedMessage, ports: transferredPorts)

            // We don't chain this promise because we want to return the
            // MessagePort details to the webview before the event is
            // resolved.
            worker.dispatchEvent(event)
                .then {
                    event.resolve(in: worker)
                }
                .catch { error in
                    Log.error?("Dispatch of MessageEvent to worker failed: \(error)")
                }

            return Promise(value: [
                "transferred": wrappedPorts.map { $0.id }
            ])
        }
    }
}
