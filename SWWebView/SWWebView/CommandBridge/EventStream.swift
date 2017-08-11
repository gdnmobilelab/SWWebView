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

    fileprivate static var currentEventStreams: [Int : EventStream] = [:]
    
    // We add a strong reference to the container here, so that we retain
    // any workers relevant to this webview. The rest of the operations rely
    // on ServiceWorkerContainer.get(), but that's fine, since this event stream
    // is the most reliable handle we have on the 'lifetime' of a webview frame.
    let container:ServiceWorkerContainer
    let task: WKURLSchemeTask
    
    var workerListener: Listener<ServiceWorker>? = nil

    fileprivate init(for task: WKURLSchemeTask) {
        self.task = task
        self.container = ServiceWorkerContainer.get(for: task.request.mainDocumentURL!)
        
        self.workerListener = GlobalEventLog.addListener { (worker:ServiceWorker) in
            if worker.url.host == self.container.containerURL.host {
                self.sendUpdate(identifier: "serviceworker", object: worker)
            }
        }
        
    }
    
    func shutdown() {
        GlobalEventLog.removeListener(self.workerListener!)
        self.workerListener = nil
    }
    
    func sendUpdate(identifier:String, object: ToJSON) {
        do {
            let json = try JSONSerialization.data(withJSONObject: object.toJSONSuitableObject(), options: [])
            let str = "\(identifier): \(json)"
            
            self.task.didReceive(str.data(using: String.Encoding.utf8)!)
        } catch {
            Log.error?("Error when trying to send update to webview: \(error)")
        }
    }
    
    static func create(for task: WKURLSchemeTask) {
        if EventStream.currentEventStreams[task.hash] != nil {
            Log.error?("Tried to create an EventStream for a task when it already exists")
            task.didFailWithError(ErrorMessage("EventStream already exists for this task"))
            return
        }
        
        let newStream = EventStream(for: task)
        EventStream.currentEventStreams[task.hash] = newStream
    }
    
    static func remove(for task: WKURLSchemeTask) {
        if EventStream.currentEventStreams[task.hash] == nil {
            Log.error?("Tried to remove an EventStream that does not exist")
        }
        EventStream.currentEventStreams[task.hash] = nil
    }
}
