//
//  SWURLSchemeTask.swift
//  SWWebView
//
//  Created by alastair.coote on 11/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorker

/// Because of the URL and body mapping we do, we need to wrap the WKURLSchemeTask class.
public class SWURLSchemeTask {

    public let request: URLRequest
    fileprivate let underlyingTask: WKURLSchemeTask
    public var open: Bool = true
    //    public let origin:URL?
    public let referrer: URL?

    // We could use request.url?, but since we've already checked in the init()
    // that the URL exists, we can provide a non-optional var here.
    //    public let url:URL

    public var originalServiceWorkerURL: URL? {
        return self.underlyingTask.request.url
    }

    // There doesn't seem to be any built in functionality for tracking when
    // a task has stopped, internal to the task itself. So we use the scheme
    // handler with this dictionary to keep track.
    static var currentlyActiveTasks: [Int: SWURLSchemeTask] = [:]

    init(underlyingTask: WKURLSchemeTask) throws {

        self.underlyingTask = underlyingTask

        guard let requestURL = underlyingTask.request.url else {
            throw ErrorMessage("Incoming task must have a URL set")
        }

        guard let modifiedURL = URL(swWebViewString: requestURL.absoluteString) else {
            throw ErrorMessage("Could not parse incoming task URL")
        }

        //        self.url = modifiedURL

        var request = URLRequest(url: modifiedURL, cachePolicy: underlyingTask.request.cachePolicy, timeoutInterval: underlyingTask.request.timeoutInterval)

        request.httpMethod = underlyingTask.request.httpMethod
        request.allHTTPHeaderFields = underlyingTask.request.allHTTPHeaderFields

        // The mainDocumentURL is not accurate inside iframes, so we're deliberately removing it
        // here, to ensure we don't ever rely on it.
        request.mainDocumentURL = nil

        //        if let origin = underlyingTask.request.value(forHTTPHeaderField: "Origin") {
        //            // We use this to detect what our container scope is
        //
        //            guard let originURL = URL(swWebViewString: origin) else {
        //                throw ErrorMessage("Could not parse Origin header correctly")
        //            }
        //
        //            self.origin = originURL
        //
        //        } else {
        //            self.origin = nil
        //        }

        if let referer = underlyingTask.request.value(forHTTPHeaderField: "Referer") {

            guard let referrerURL = URL(swWebViewString: referer) else {
                throw ErrorMessage("Could not parse Referer header correctly")
            }
            self.referrer = referrerURL
        } else {
            self.referrer = nil
        }

        // Because WKURLSchemeTask doesn't receive POST bodies (rdar://33814386) we have to
        // graft them into a header. Gross. Hopefully this gets fixed.

        let graftedBody = underlyingTask.request.value(forHTTPHeaderField: SWWebViewBridge.graftedRequestBodyHeader)

        if let body = graftedBody {
            request.httpBody = body.data(using: .utf8)
        }

        self.request = request

        SWURLSchemeTask.currentlyActiveTasks[self.hash] = self
    }

    func close() {
        self.open = false
        SWURLSchemeTask.currentlyActiveTasks.removeValue(forKey: self.hash)
    }

    static func getExistingTask(for task: WKURLSchemeTask) -> SWURLSchemeTask? {
        return self.currentlyActiveTasks[task.hash]
    }

    public func didReceive(_ data: Data) throws {
        if self.open == false {
            Log.warn?("URL task trying to send data to a closed connection")
            return
        }
        self.underlyingTask.didReceive(data)
    }

    public func didReceiveHeaders(statusCode: Int, headers: [String: String] = [:]) throws {

        var modifiedHeaders = headers
        // Always want to make sure API responses aren't cached
        modifiedHeaders["Cache-Control"] = "no-cache"

        guard let originalWorkerURL = self.originalServiceWorkerURL else {
            throw ErrorMessage("No original service worker URL available")
        }

        guard let response = HTTPURLResponse(url: originalWorkerURL, statusCode: statusCode, httpVersion: nil, headerFields: modifiedHeaders) else {
            throw ErrorMessage("Was not able to create HTTPURLResponse, unknown reason")
        }

        if self.open == false {
            throw ErrorMessage("Task is no longer open")
        }

        self.underlyingTask.didReceive(response)
    }

    public func didFinish() throws {

        if self.open == false {
            Log.warn?("URL task trying to finish an already closed connection")
            return
        }
        self.underlyingTask.didFinish()
        self.close()
    }

    /// This doesn't throw because what's the point - if it fails, it fails
    public func didFailWithError(_ error: Error) {
        if self.open == false {
            Log.warn?("URL task trying to finish with error when it's already finished")
            return
        }
        self.underlyingTask.didFailWithError(error)
        self.close()
    }

    var hash: Int {
        return self.underlyingTask.hash
    }
}
