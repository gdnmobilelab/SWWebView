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

class EventStream {

    fileprivate static var currentEventStreams: [Int: EventStream] = [:]

    // We add a strong reference to the container here, so that we retain
    // any workers relevant to this webview. The rest of the operations rely
    // on ServiceWorkerContainer.get(), but that's fine, since this event stream
    // is the most reliable handle we have on the 'lifetime' of a webview frame.
    let container: ServiceWorkerContainer
    let task: SWURLSchemeTask

    var workerListener: Listener<ServiceWorker>?
    var registrationListener: Listener<ServiceWorkerRegistration>?

    fileprivate init(for task: SWURLSchemeTask) {
        self.task = task
        self.container = ServiceWorkerContainer.get(for: task.request.mainDocumentURL!)

        self.workerListener = GlobalEventLog.addListener { (worker: ServiceWorker) in
            if worker.url.host == self.container.containerURL.host {
                self.sendUpdate(identifier: "serviceworker", object: worker)
            }
        }

        self.registrationListener = GlobalEventLog.addListener { (reg: ServiceWorkerRegistration) in
            if reg.scope.host == self.container.containerURL.host {
                self.sendUpdate(identifier: "serviceworkerregistration", object: reg)
            }
        }

        let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
        ])!

        task.didReceive(response)
    }

    func shutdown() {
        GlobalEventLog.removeListener(self.workerListener!)
        GlobalEventLog.removeListener(self.registrationListener!)
        self.workerListener = nil
        self.registrationListener = nil
    }

    func sendUpdate(identifier: String, object: ToJSON) {
        do {
            let json = try JSONSerialization.data(withJSONObject: object.toJSONSuitableObject(), options: [])
            let jsonString = String(data: json, encoding: .utf8)!
            let str = "\(identifier): \(jsonString)"

            self.task.didReceive(str.data(using: String.Encoding.utf8)!)
        } catch {
            Log.error?("Error when trying to send update to webview: \(error)")
        }
    }

    static func create(for task: SWURLSchemeTask) {
        if EventStream.currentEventStreams[task.hash] != nil {
            Log.error?("Tried to create an EventStream for a task when it already exists")
            task.didFailWithError(ErrorMessage("EventStream already exists for this task"))
            return
        }

        let newStream = EventStream(for: task)
        EventStream.currentEventStreams[task.hash] = newStream
    }

    static func remove(for task: SWURLSchemeTask) {
        let h = task.hash
        if EventStream.currentEventStreams[task.hash] == nil {
            Log.error?("Tried to remove an EventStream that does not exist")
        }
        EventStream.currentEventStreams[task.hash]!.shutdown()
        EventStream.currentEventStreams[task.hash] = nil
    }
}
