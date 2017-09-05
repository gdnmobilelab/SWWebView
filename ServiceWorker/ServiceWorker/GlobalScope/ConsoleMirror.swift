//
//  Console.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc private protocol ConsoleMirrorExports: JSExport {
    func mirror(_ level: String, _ msg: JSValue)
}

/// JavascriptCore has a fully functional console, just like the browser. But ideally we will also
/// mirror JSC console statements in our logs, too. There are no console events as such, so we have
/// to override the functions on the console object itself.
@objc class ConsoleMirror: NSObject, ConsoleMirrorExports {

    init(console: JSValue) throws {
        super.init()
        let interceptorJS = """
            var originalFunction = console[level];
            console[level] = function() {
                originalFunction.apply(console,arguments);
                interceptor.mirror(level, Array.from(arguments));
            }
        """

        // Yet to find a better way of doing this, but this runs:
        // new Function(level, interceptor, {js})
        // to create a function we then apply to each console level we want to mirror.

        guard let interceptorFunc = console.context
            .objectForKeyedSubscript("Function")
            .construct(withArguments: ["level", "interceptor", interceptorJS]) else {
            throw ErrorMessage("Could not construct JS console interceptor")
        }

        // Now replace the functions on the console object for each level

        interceptorFunc.call(withArguments: ["info", self])
        interceptorFunc.call(withArguments: ["log", self])
        interceptorFunc.call(withArguments: ["warn", self])
        interceptorFunc.call(withArguments: ["error", self])
        interceptorFunc.call(withArguments: ["debug", self])
    }

    fileprivate func mirror(_ level: String, _ msg: JSValue) {

        let values = msg.toArray()
            .map { String(describing: $0) }
            .joined(separator: ",")

        switch level {
        case "info":
            Log.info?(values)
        case "log":
            Log.info?(values)
        case "debug":
            Log.debug?(values)
        case "warn":
            Log.warn?(values)
        case "error":
            Log.error?(values)
        default:
            Log.error?("Tried to log to JSC console at an unknown level.")
        }
    }
}
