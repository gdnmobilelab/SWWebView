//
//  SWURLSchemeTask.swift
//  SWWebView
//
//  Created by alastair.coote on 11/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit

/// Because of the URL and body mapping we do, we need to wrap the WKURLSchemeTask class.
public class SWURLSchemeTask {

    public let request: URLRequest
    fileprivate let underlyingTask: WKURLSchemeTask
    public var open:Bool = true
    public let origin:URL?
    public var originalServiceWorkerURL:URL {
        get {
            return self.underlyingTask.request.url!
        }
    }
    
    // There doesn't seem to be any built in functionality for tracking when
    // a task has stopped, internal to the task itself. So we use the scheme
    // handler with this dictionary to keep track.
    static var currentlyActiveTasks: [Int: SWURLSchemeTask] = [:]

    init(underlyingTask: WKURLSchemeTask) {

        self.underlyingTask = underlyingTask
        
        let modifiedURL = URL(swWebViewString: underlyingTask.request.url!.absoluteString)!
        let modifiedDocumentURL = URL(swWebViewString: underlyingTask.request.mainDocumentURL!.absoluteString)!

        var request = URLRequest(url: modifiedURL, cachePolicy: underlyingTask.request.cachePolicy, timeoutInterval: underlyingTask.request.timeoutInterval)
        
        request.httpMethod = underlyingTask.request.httpMethod
        request.allHTTPHeaderFields = underlyingTask.request.allHTTPHeaderFields
        request.mainDocumentURL = modifiedDocumentURL
        
        if let origin = underlyingTask.request.value(forHTTPHeaderField: "Origin") {
            // We use this to detect what our container scope is
            self.origin = URL(swWebViewString: origin)
            
        } else {
            self.origin = nil
        }
        
        // Because WKURLSchemeTask doesn't receive POST bodies (rdar://33814386) we have to
        // graft them into a header. Gross. Hopefully this gets fixed.

        let graftedBody = underlyingTask.request.value(forHTTPHeaderField: SWSchemeHandler.graftedRequestBodyHeader)

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
            NSLog("DEAD JIM \(self.request.url!.absoluteString)")
            return
        }
        self.underlyingTask.didReceive(data)
    }

    public func didReceive(_ response: URLResponse) throws {
        if self.open == false {
            NSLog("DEAD JIM RECEIVE \(self.request.url!.absoluteString)")
            return
        }
        self.underlyingTask.didReceive(response)
    }

    public func didFinish() throws {
        
        if self.open == false {
            NSLog("DEAD JIM FINISH \(self.request.url!.absoluteString)")
            return
        }
        self.underlyingTask.didFinish()
    }

    
    /// This doesn't throw because what's the point - if it fails, it fails
    public func didFailWithError(_ error: Error) {
        if self.open == false {
            NSLog("DEAD JIM FAIL \(self.request.url!.absoluteString)")
            return
        }
        self.underlyingTask.didFailWithError(error)
    }

    var hash: Int {
        return self.underlyingTask.hash
    }
}
