//
//  SWURLSchemeTask.swift
//  SWWebView
//
//  Created by alastair.coote on 11/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit

public class SWURLSchemeTask {
    
    public let request: URLRequest
    fileprivate let underlyingTask: WKURLSchemeTask
    
    init(underlyingTask: WKURLSchemeTask) {
        
        self.underlyingTask = underlyingTask
        
        var modifiedURL = URLComponents(url: underlyingTask.request.url!, resolvingAgainstBaseURL: true)!
        modifiedURL.scheme = modifiedURL.host == "localhost" ? "http" : "https"
        
        var modifiedDocumentURL = URLComponents(url: underlyingTask.request.mainDocumentURL!, resolvingAgainstBaseURL: true)!
        modifiedDocumentURL.scheme = modifiedURL.host == "localhost" ? "http" : "https"
        
        var request = URLRequest(url: modifiedURL.url!, cachePolicy: underlyingTask.request.cachePolicy, timeoutInterval: underlyingTask.request.timeoutInterval)
        
        request.mainDocumentURL = modifiedDocumentURL.url!
        
        // Because WKURLSchemeTask doesn't receive POST bodies (rdar://33814386) we have to
        // graft them into a header. Gross. Hopefully this gets fixed.
        
        let graftedBody = underlyingTask.request.value(forHTTPHeaderField: SWSchemeHandler.graftedRequestBodyHeader)
        
        if let body = graftedBody {
            request.httpBody = body.data(using: .utf8)
        }
        
        self.request = request
        
    }
    
    public func didReceive(_ data: Data) {
        self.underlyingTask.didReceive(data)
    }
    
    public func didReceive(_ response: URLResponse) {
        self.underlyingTask.didReceive(response)
    }
    
    public func didFinish() {
        self.underlyingTask.didFinish()
    }
    
    public func didFailWithError(_ error: Error) {
        self.underlyingTask.didFailWithError(error)
    }
    
    var hash:Int {
        get {
            return self.underlyingTask.hash
        }
    }
    
    
}
