//
//  GlobalFetch.swift
//  ServiceWorker
//
//  Created by alastair.coote on 06/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import JavaScriptCore

@objc public class FetchSession: NSObject, URLSessionDelegate, URLSessionDataDelegate {

    // We store all our pending responses here so that we can send the
    // appropriate delegate methods on. But we don't store strong references
    // because the JS could dispose of a fetch task at any point - if it does
    // we'll stop downloading
    fileprivate var pendingTasks = NSHashTable<FetchTask>.weakObjects()

    static let `default` = FetchSession()

    fileprivate var session: URLSession!

    fileprivate var tasksWithoutResponsesYet = Set<FetchTask>()

    override init() {
        super.init()
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }

    public func fetch(_ url: URL) -> Promise<FetchResponseProtocol> {
        let request = FetchRequest(url: url)
        return self.fetch(request)
    }

    public func fetch(_ request: FetchRequest, fromOrigin: URL? = nil) -> Promise<FetchResponseProtocol> {

        return self.performCORSCheck(for: request, inOrigin: fromOrigin)
            .then { corsRestrictions in

                let nsRequest = request.toURLRequest()
                let task = self.session.dataTask(with: nsRequest)

                // We use the task wrapper to track which responsea are attached to the task.
                // Most of the time there is a 1:1 relationship, but if we use response.clone()
                // then more than one will be attached.
                let fetchTask = FetchTask(for: task, with: request)

                self.pendingTasks.add(fetchTask)

                // This could do with being revisited, but the reference to the fetchTask is lost
                // while the promise is evaluating (because there is no FetchResponse for it yet)
                // which we don't want. So we temporarily keep a strong reference

                self.tasksWithoutResponsesYet.insert(fetchTask)

                task.resume()
                return fetchTask.hasResponse
                    .then { response -> FetchResponseProtocol in

                        if request.mode == .NoCORS && corsRestrictions.isCrossDomain == true {
                            return try OpaqueResponse(from: response)
                        } else if request.mode == .CORS && corsRestrictions.isCrossDomain == true {
                            return try CORSResponse(from: response, allowedHeaders: corsRestrictions.allowedHeaders)
                        } else {
                            return try BasicResponse(from: response)
                        }
                    }
                    .always {
                        self.tasksWithoutResponsesYet.remove(fetchTask)
                    }
            }
    }

    internal func fetch(_ requestOrURL: JSValue, fromOrigin origin: URL) -> JSValue? {

        return firstly { () -> Promise<FetchResponseProtocol> in

            var request: FetchRequest

            if let fetchInstance = requestOrURL.toObjectOf(FetchRequest.self) as? FetchRequest {
                request = fetchInstance
            } else if requestOrURL.isString {

                guard let requestString = requestOrURL.toString() else {
                    throw ErrorMessage("Could not convert request to string")
                }

                guard let parsedURL = URL(string: requestString) else {
                    throw ErrorMessage("Could not parse URL string")
                }

                request = FetchRequest(url: parsedURL)
            } else {
                throw ErrorMessage("Did not understand first argument passed in")
            }

            return self.fetch(request, fromOrigin: origin)

        }.toJSPromise(in: requestOrURL.context)
    }

    fileprivate func performCORSCheck(for request: FetchRequest, inOrigin: URL?) -> Promise<FetchCORSRestrictions> {

        guard let origin = inOrigin else {
            // No origin - no CORS check to perform
            return Promise(value: FetchCORSRestrictions(isCrossDomain: false, allowedHeaders: []))
        }

        guard let host = origin.host, let scheme = origin.scheme else {
            return Promise(error: ErrorMessage("Origin must have a host and a scheme"))
        }

        if request.mode != .CORS || origin.host == request.url.host {
            // This is not a CORS request, so we can skip all this.
            return Promise(value: FetchCORSRestrictions(isCrossDomain: false, allowedHeaders: []))
        }

        let optionsRequest = FetchRequest(url: request.url)
        optionsRequest.method = "OPTIONS"

        return self.fetch(optionsRequest)
            .then { res -> FetchCORSRestrictions in

                let allowedOrigin = res.headers.get("Access-Control-Allow-Origin")

                if allowedOrigin != "*" && allowedOrigin != scheme + "://" + host {
                    throw ErrorMessage("Access-Control-Allow-Origin does not match or does not exist")
                }

                /// TODO: Do we throw an error if this header doesn't exist?
                if let allowedMethods = res.headers.get("Access-Control-Allow-Methods") {
                    let allowedMethodsSplit = allowedMethods
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

                    if allowedMethodsSplit.contains(request.method) == false {
                        throw ErrorMessage("Method not supported in CORS")
                    }
                }

                var exposedHeaders: [String] = []

                if let exposedHeadersHeader = res.headers.get("Access-Control-Expose-Headers") {
                    exposedHeaders = exposedHeadersHeader
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                }

                return FetchCORSRestrictions(isCrossDomain: true, allowedHeaders: exposedHeaders)
            }
    }

    fileprivate func findFetchTask(for task: URLSessionTask) -> FetchTask? {
        return self.pendingTasks.allObjects.first(where: { $0.task == task })
    }

    public func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

        guard let taskWrapper = self.findFetchTask(for: task) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return completionHandler(nil)
        }

        if taskWrapper.shouldFollowRedirect() {
            completionHandler(newRequest)
        } else {
            completionHandler(nil)
        }
    }

    public func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error?("URLResponse was not an HTTPURLResponse")
            return completionHandler(.cancel)
        }

        guard let taskWrapper = self.findFetchTask(for: dataTask) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return completionHandler(.cancel)
        }

        do {
            try taskWrapper.receive(initialResponse: httpResponse, withCompletionHandler: completionHandler)
        } catch {
            Log.error?("\(error)")
        }
    }

    public func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

        guard let taskWrapper = self.findFetchTask(for: dataTask) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return dataTask.cancel()
        }

        taskWrapper.receive(data: data)
    }

    public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        guard let taskWrapper = self.findFetchTask(for: task) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return task.cancel()
        }

        self.pendingTasks.remove(taskWrapper)

        taskWrapper.end(withError: error)
    }
}
