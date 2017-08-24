//
//  WindowClient.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol WindowClientExports : JSExport {
    func focus() -> JSValue
    func navigate(_ url: String) -> JSValue
    var focused:Bool { get }
    var visibilityState: String {get}
}


@objc class WindowClient : Client, WindowClientExports {
    
    let wrapAroundWindow: WindowClientProtocol
    
    init(wrapping: WindowClientProtocol, in context: JSContext) {
        self.wrapAroundWindow = wrapping
        super.init(wrapping: wrapping, in: context)
    }
    
    func focus() -> JSValue {
        let jsp = JSPromise(context: self.context)
        self.wrapAroundWindow.focus { err, windowClientProtocol in
            if err != nil {
                jsp.reject(err!)
            } else {
                jsp.fulfill(Client.getOrCreate(from: windowClientProtocol!, in: self.context))
            }
        }
        return jsp.jsValue
    }
    
    func navigate(_ url: String) -> JSValue {
        
        let jsp = JSPromise(context: self.context)
        
        guard let parsedURL = URL(string: url, relativeTo: nil) else {
            jsp.reject(ErrorMessage("Could not parse URL returned by native implementation"))
            return jsp.jsValue
        }
        
        self.wrapAroundWindow.navigate(to: parsedURL) { err, windowClient in
            if err != nil {
                jsp.reject(err!)
            } else {
                jsp.fulfill(Client.getOrCreate(from: windowClient!, in: self.context))
            }
        }
        
        return jsp.jsValue
        
    }
    
    var focused: Bool {
        get {
            return self.wrapAroundWindow.focused
        }
    }
    
    var visibilityState: String {
        get {
            return self.wrapAroundWindow.visibilityState.stringValue
        }
    }
    
    
}
