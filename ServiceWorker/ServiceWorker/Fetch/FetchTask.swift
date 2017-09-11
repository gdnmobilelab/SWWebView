//
//  FetchTask.swift
//  ServiceWorker
//
//  Created by alastair.coote on 08/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

class FetchTask: NSObject {

    let task: URLSessionDataTask
    let request: FetchRequest

    // We don't want to keep these responses if whatever JS code is using them
    // disposes of them
    var responses = NSHashTable<FetchResponse>.weakObjects()

    fileprivate let hasResponsePromise = Promise<FetchResponse>.pending()

    fileprivate var completionHandler: ((URLSession.ResponseDisposition) -> Void)?

    var hasResponse: Promise<FetchResponse> {
        return self.hasResponsePromise.promise
    }

    init(for task: URLSessionDataTask, with request: FetchRequest) {
        self.task = task
        self.request = request
        super.init()
    }

    deinit {
        if self.task.state == .running {
            Log.info?("Cancelling running fetch task because nothing is listening to it")
            self.task.cancel()
        }
    }

    fileprivate var redirected = false

    func shouldFollowRedirect() -> Bool {
        self.redirected = true
        if self.request.redirect == .Follow {
            return true
        }

        if self.request.redirect == .Error {
            self.hasResponsePromise.reject(ErrorMessage("Received redirect, FetchRequest redirect set to 'error'"))
        }

        return false
    }

    func beginDownloadIfNotAlreadyStarted() {
        if let handler = self.completionHandler {
            handler(.allow)
            self.completionHandler = nil
        }
    }

    func receive(initialResponse: HTTPURLResponse, withCompletionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void) throws {

        guard let url = initialResponse.url else {
            throw ErrorMessage("HTTPURLResponse has no URL")
        }

        self.completionHandler = handler

        let headers = FetchHeaders()

        try initialResponse.allHeaderFields.forEach { key, val in
            guard let keyString = key as? String, let valString = val as? String else {
                throw ErrorMessage("Could not parse HTTPURLResponse headers")
            }
            headers.append(keyString, valString)
        }

        let fetchResponse = FetchResponse(request: self.request, url: url, headers: headers, status: initialResponse.statusCode, redirected: self.redirected)

        // Establish a strong reference between the response and task
        fetchResponse.fetchTask = self
        self.add(response: fetchResponse)
        self.hasResponsePromise.fulfill(fetchResponse)
    }

    func receive(data: Data) {
        self.responses.allObjects.forEach { $0.receiveData(data) }
    }

    func end(withError error: Error? = nil) {
        self.responses.allObjects.forEach { response in
            response.streamEnded(withError: error)
            // break strong reference now that we don't need it any more
            response.fetchTask = nil
        }
    }

    func add(response: FetchResponse) {
        self.responses.add(response)
    }
}
