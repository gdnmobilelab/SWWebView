//
//  MultiDataDelegate.swift
//  ServiceWorker
//
//  Created by alastair.coote on 14/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

/// We want multiple FetchResponses to be able to listen to this (in case they are cloned)
/// so we use this delegate as a means to attach multiple delegates.
@objc public class MultiDataDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {

    var listeners: [URLSessionDataDelegate & URLSessionDownloadDelegate] = []

    func add(delegate: URLSessionDataDelegate & URLSessionDownloadDelegate) {
        self.listeners.append(delegate)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.listeners.forEach { l in
            l.urlSession?(session, dataTask: dataTask, didReceive: data)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.listeners.forEach { l in
            l.urlSession?(session, task: task, didCompleteWithError: error)
        }
        self.listeners.removeAll()
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        self.listeners.forEach { l in
            l.urlSession?(session, didBecomeInvalidWithError: error)
        }
        self.listeners.removeAll()
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        self.listeners.forEach { l in
            l.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.listeners.forEach { l in
            l.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }
        self.listeners.removeAll()
    }
}
