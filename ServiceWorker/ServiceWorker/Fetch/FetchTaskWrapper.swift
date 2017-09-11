////
////  FetchTaskWrapper.swift
////  ServiceWorker
////
////  Created by alastair.coote on 07/09/2017.
////  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
////
//
// import Foundation
// import PromiseKit
//
///// We keep strong references to our tasks - when those references
///// all go away, we know the fetch isn't being used any more. In that case,
///// we can cancel the task. URLSession keeps its own strong references to
///// the task while it's running, but not this wrapper.
// @objc class FetchTaskWrapper: NSObject {
//
//    let task: URLSessionDataTask
//    let request: FetchRequest
//    fileprivate var attachedResponses = NSHashTable<FetchResponse>.weakObjects()
//
//    var responses: [FetchResponse] {
//        return self.attachedResponses.allObjects
//    }
//
//    func add(response: FetchResponse) {
//        self.attachedResponses.add(response)
//        if self.attachedResponses.count == 1 {
//            self.hasResponsePromise.fulfill(response)
//        }
//    }
//
//    fileprivate let hasResponsePromise = Promise<FetchResponse>.pending()
//
//    var hasResponse: Promise<FetchResponse> {
//        return self.hasResponsePromise.promise
//    }
//
//    init(for request: FetchRequest, task: URLSessionDataTask) {
//        self.task = task
//        self.request = request
//    }
//
//    var redirected  = false
//
//    func shouldFollowRedirect() -> Bool {
//        self.redirected = true
//        if self.request.redirect == .Follow {
//            return true
//        }
//
//        if self.request.redirect == .Error {
//            self.hasResponsePromise.reject(ErrorMessage("Received redirect, FetchRequest redirect set to 'error'"))
//        }
//
//        return false
//    }
//
//    deinit {
//        if self.task.state == .running {
//            Log.info?("Closing fetch task automatically: \(self.task.currentRequest?.url?.absoluteString ?? "(no URL)")")
//            self.task.cancel()
//        }
//    }
// }
