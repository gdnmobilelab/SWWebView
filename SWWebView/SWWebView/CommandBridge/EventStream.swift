//
//  EventStream.swift
//  SWWebView
//
//  Created by alastair.coote on 09/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorker
import ServiceWorkerContainer

class EventStream: NSObject {

    // We add a strong reference to the container here, so that we retain
    // any workers relevant to this webview. The rest of the operations rely
    // on ServiceWorkerContainer.get(), but that's fine, since this event stream
    // is the most reliable handle we have on the 'lifetime' of a webview frame.
    let container: ServiceWorkerContainer
    let task: SWURLSchemeTask

    var workerListener: Listener<ServiceWorker>?
    var registrationListener: Listener<ServiceWorkerRegistration>?
    var containerListener: Listener<ServiceWorkerContainer>?
    var workerInstallErrorListener: Listener<WorkerInstallationError>?

    func isScopeMatch(_ url: URL) -> Bool {
        return url.host == self.container.url.host && url.port == self.container.url.port
    }

    init(for task: SWURLSchemeTask, withContainer container: ServiceWorkerContainer) throws {
        self.task = task

        self.container = container
        super.init()
        self.workerListener = GlobalEventLog.addListener { (worker: ServiceWorker) in
            if self.isScopeMatch(worker.url) {
                self.sendUpdate(identifier: "serviceworker", object: worker)
            }
        }

        self.registrationListener = GlobalEventLog.addListener { (reg: ServiceWorkerRegistration) in
            if self.isScopeMatch(reg.scope) {
                self.sendUpdate(identifier: "serviceworkerregistration", object: reg)
            }
        }

        self.containerListener = GlobalEventLog.addListener { (container: ServiceWorkerContainer) in
            if container == self.container {
                self.sendUpdate(identifier: "serviceworkercontainer", object: container)
            }
        }

        self.workerInstallErrorListener = GlobalEventLog.addListener { workerError in
            if workerError.container == self.container {
                self.sendUpdate(identifier: "workerinstallerror", object: workerError)
            }
        }

        try task.didReceiveHeaders(statusCode: 200, headers: [
            "Content-Type": "text/event-stream",
        ])

        // It's possible that this event stream was interrupted as a result of the page being
        // shown/hidden/who knows, so the JS objects might be out of date. To make sure we're
        // clear, we'll send down the details for every relevant object.

        self.sendUpdate(identifier: "serviceworkercontainer", object: self.container)

        // Because the container doesn't contain a direct reference to its registrations,
        // we manually grab them, and send them down as well.
        self.container.getRegistrations()
            .then { regs in
                // Registrations send down their corresponding worker objects, so we don't
                // need to push those too.
                regs.forEach { self.sendUpdate(identifier: "serviceworkeregistration", object: $0) }
            }
    }

    func shutdown() {
        GlobalEventLog.removeListener(self.workerListener!)
        GlobalEventLog.removeListener(self.registrationListener!)
        GlobalEventLog.removeListener(self.containerListener!)
        self.workerListener = nil
        self.registrationListener = nil
    }

    func sendUpdate(identifier: String, object: ToJSON) {
        do {
            let json = try JSONSerialization.data(withJSONObject: object.toJSONSuitableObject(), options: [])
            let jsonString = String(data: json, encoding: .utf8)!
            let str = "\(identifier): \(jsonString)\n"

            try self.task.didReceive(str.data(using: String.Encoding.utf8)!)
        } catch {
            Log.error?("Error when trying to send update to webview: \(error)")
        }
    }

    //    static func create(for task: SWURLSchemeTask) {
    //        if EventStream.currentEventStreams[task.hash] != nil {
    //            Log.error?("Tried to create an EventStream for a task when it already exists")
    //            task.didFailWithError(ErrorMessage("EventStream already exists for this task"))
    //            return
    //        }
    //        do {
    //            let newStream = try EventStream(for: task)
    //            EventStream.currentEventStreams[task.hash] = newStream
    //        } catch {
    //            task.didFailWithError(error)
    //        }
    //    }
    //
    //    static func remove(for task: SWURLSchemeTask) {
    //        if EventStream.currentEventStreams[task.hash] == nil {
    //            Log.error?("Tried to remove an EventStream that does not exist")
    //        }
    //        EventStream.currentEventStreams[task.hash]!.shutdown()
    //        EventStream.currentEventStreams[task.hash] = nil
    //    }
}
