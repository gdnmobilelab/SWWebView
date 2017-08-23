//
//  SWWebViewBridge.swift
//  SWWebView
//
//  Created by alastair.coote on 23/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorkerContainer
import ServiceWorker
import PromiseKit

public class SWWebViewBridge : NSObject, WKURLSchemeHandler {
    
    static let serviceWorkerRequestMethod = "SW_REQUEST"
    static let graftedRequestBodyHeader = "X-Grafted-Request-Body"
    static let eventStreamPath = "/events"
    
    public typealias Command = (ServiceWorkerContainer, AnyObject?) throws -> Promise<Any?>?
    
    public static var routes: [String: Command] = [
        "/ServiceWorkerContainer/register": ServiceWorkerContainerCommands.register,
        "/ServiceWorkerContainer/getregistration": ServiceWorkerContainerCommands.getRegistration,
        "/ServiceWorkerContainer/getregistrations": ServiceWorkerContainerCommands.getRegistrations,
        "/ServiceWorkerRegistration/unregister": ServiceWorkerRegistrationCommands.unregister,
        ]
    
    
    // These are two separate sets because multiple EventStreams can share a
    // ServiceWorkerContainer. Technically they shouldn't, but we don't have
    // any way of differentating them when requests come in.
    var containers = Set<ServiceWorkerContainer>()
    var eventStreams = Set<EventStream>()
   
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        
        // WKURLSchemeTask can fail even when using didFailWithError if the task
        // has already been closed. We handle that in SWURLSchemeTask but first
        // we need to create one. So one first catch:
        
        let modifiedTask:SWURLSchemeTask
        do {
            modifiedTask = try SWURLSchemeTask(underlyingTask: urlSchemeTask)
        } catch {
            urlSchemeTask.didFailWithError(error)
            return
        }
        
        // And now that we've got the task set up, we can run async promises without
        // worrying about if the task will fail.
        
        firstly { () -> Promise<Void> in
            
            if modifiedTask.request.httpMethod == SWWebViewBridge.serviceWorkerRequestMethod {
                return try self.startServiceWorkerTask(modifiedTask)
            }
//            else if modifiedTask.request.httpMethod == "OPTIONS" && modifiedTask.request.url?.host == SWWebViewBridge.serviceWorkerRequestHost {
//                // The browser will send CORS preflight requests for SW API calls. We need to reply
//                // appropriately.
//
//                try modifiedTask.didReceiveHeaders(statusCode: 200, headers: [
//                    "Access-Control-Allow-Methods": SWWebViewBridge.serviceWorkerRequestMethod,
//                    "Access-Control-Allow-Headers": [
//                        "content-type",
//                        "origin",
//                        "referer",
//                        SWWebViewBridge.graftedRequestBodyHeader
//                    ].joined(separator: ",")
//                ])
//                try modifiedTask.didFinish()
//                return Promise(value: ())
//            }
            
            // Need to flesh this out, but for now we're using this for tests
            let req = FetchRequest(url: modifiedTask.request.url!)
            req.cache = .NoCache
    
            return FetchOperation.fetch(req)
                .then { res -> Promise<Data> in
    
                    var headerDict: [String: String] = [:]
                    res.headers.keys().forEach { header in
                        headerDict[header] = res.headers.get(header)
                    }
    
                    headerDict["Cache-Control"] = "no-cache"
                    
                    try modifiedTask.didReceiveHeaders(statusCode: res.status, headers: headerDict)
                    
                    return res.data()
                }
                .then { data -> Void in
                    try modifiedTask.didReceive(data)
                    try modifiedTask.didFinish()
                }
            
        }
            .catch { error in
                
                do {
                    // try to send the full error, if that fails, just use the native error handling
                    try modifiedTask.didReceiveHeaders(statusCode: 500)
                    
                    let errorJSON = try JSONSerialization.data(withJSONObject: ["error" : "\(error)"], options: [])
                    
                    try modifiedTask.didReceive(errorJSON)
                    try modifiedTask.didFinish()
                } catch {
                    modifiedTask.didFailWithError(error)
                }
                
        }
        
        
        
    }
    
    func startServiceWorkerTask(_ task: SWURLSchemeTask) throws -> Promise<Void> {
        
        guard let requestURL = task.request.url else {
            throw ErrorMessage("Cannot start a task with no URL")
        }
        
        if requestURL.path == SWWebViewBridge.eventStreamPath {
            
            try self.startEventStreamTask(task)
            
            // Since the event stream stays alive indefinitely, we just early return
            // a void promise
            return Promise(value: ())
        }
        
        guard let referrer = task.referrer else {
            throw ErrorMessage("All non-event stream SW API tasks must send a referer header")
        }
        
        guard let container = self.containers.first(where: { $0.containerURL.absoluteString == referrer.absoluteString}) else {
            throw ErrorMessage("ServiceWorkerContainer should already exist before any tasks are run")
        }
        
        guard let matchingRoute = SWWebViewBridge.routes.first(where: { $0.key == requestURL.path})?.value else {
            // We don't recognise this URL, so we just return a 404.
            try task.didReceiveHeaders(statusCode: 404)
            try task.didFinish()
            return Promise(value: ())
        }
        
        var jsonBody: AnyObject?
        if let body = task.request.httpBody {
            jsonBody = try JSONSerialization.jsonObject(with: body, options: []) as AnyObject
        }
        
        return firstly { () -> Promise<Any?> in
            guard let promise = try matchingRoute(container, jsonBody) else {
                // The task didn't return an async promise, so we can just
                // return immediately
                return Promise(value: nil)
            }
            // Otherwise, wait for the return
            return promise
        }

            .then { response in
                var encodedResponse = "null".data(using: .utf8)!
                if let responseExists = response {
                    encodedResponse = try JSONSerialization.data(withJSONObject: responseExists, options: [])
                }
                try task.didReceiveHeaders(statusCode: 200, headers: [
                    "Content-Type": "application/json"
                    ])
                try task.didReceive(encodedResponse)
                try task.didFinish()
                return Promise(value: ())
        }
        
    }
    
    func startEventStreamTask(_ task: SWURLSchemeTask) throws {
    
        guard let requestURL = task.request.url else {
            throw ErrorMessage("Cannot start event stream with no URL")
        }
        
        // We send in the path of the current page as a query string param. Let's extract it.
        
        guard let path = URLComponents(url: requestURL, resolvingAgainstBaseURL: true)?
            .queryItems?.first(where: { $0.name == "path"})?.value else {
            throw ErrorMessage("Could not parse incoming URL")
        }
        
        guard let fullPageURL = URL(string: path, relativeTo: requestURL) else {
            throw ErrorMessage("Could not parse path-relative URL")
        }
        
        let container = try self.containers.first(where: {$0.containerURL.absoluteString == fullPageURL.absoluteString}) ?? {
            let newContainer = try ServiceWorkerContainer(forURL: fullPageURL.absoluteURL)
            self.containers.insert(newContainer)
            return newContainer
        }()
        
        let newStream = try EventStream(for: task, withContainer: container)
        self.eventStreams.insert(newStream)
    }
    
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        
        guard let existingTask = SWURLSchemeTask.getExistingTask(for: urlSchemeTask) else {
            Log.error?("Stopping a task that isn't currently running - this should never happen")
            return
        }
        existingTask.close()
        if let stream = self.eventStreams.first(where: { $0.task.hash == existingTask.hash }) {
            stream.shutdown()
            self.eventStreams.remove(stream)
            
            if self.eventStreams.first(where: { $0.container == stream.container}) == nil {
                // We have no other streams using this container, so we can safely remove it.
                self.containers.remove(stream.container)
            }
        }
        
       
        
    }
    
    
    
}
