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

    var originalConsole: JSValue?

    init(in context: JSContext) throws {
        self.originalConsole = context.globalObject.objectForKeyedSubscript("console")
        super.init()

        guard let proxyFunc = context.evaluateScript("""
             (function(funcToCall) {
                let levels = ["debug", "info", "warn", "error", "log"];
                let originalConsole = console;

                let levelProxy = {
                    apply: function(target, thisArg, argumentsList) {
                        // send to original console logging function
                        target.apply(thisArg, argumentsList);

                        let level = levels.find(l => originalConsole[l] == target);

                        funcToCall(level, argumentsList);
                    }
                };

                let interceptors = levels.map(
                    l => new Proxy(originalConsole[l], levelProxy)
                );

                return new Proxy(originalConsole, {
                    get: function(target, name) {
                        let idx = levels.indexOf(name);
                        if (idx === -1) {
                            // not intercepted
                            return target[name];
                        }
                        return interceptors[idx];
                    }
                });
            })

        """) else {
            throw ErrorMessage("Cannot create console proxy")
        }

        let mirrorConvention: @convention(block) (String, JSValue) -> Void = self.mirror

        guard let consoleProxy = proxyFunc.call(withArguments: [unsafeBitCast(mirrorConvention, to: AnyObject.self)]) else {
            throw ErrorMessage("Could not create instance of console proxy")
        }

        GlobalVariableProvider.add(variable: consoleProxy, to: context, withName: "console")

        // Yet to find a better way of doing this, but this runs:
        // new Function(level, interceptor, {js})
        // to create a function we then apply to each console level we want to mirror.

        //        guard let interceptorFunc = context
        //            .objectForKeyedSubscript("Function")
        //            .construct(withArguments: ["level", "interceptor", interceptorJS]) else {
        //            throw ErrorMessage("Could not construct JS console interceptor")
        //        }
        //
        //        // Now replace the functions on the console object for each level
        //
        //        interceptorFunc.call(withArguments: ["info", self])
        //        interceptorFunc.call(withArguments: ["log", self])
        //        interceptorFunc.call(withArguments: ["warn", self])
        //        interceptorFunc.call(withArguments: ["error", self])
        //        interceptorFunc.call(withArguments: ["debug", self])
    }

    //    func cleanup() {
    //        guard let console = self.originalConsole else {
    //            Log.error?("Cleanup with no original console. This should not happen.")
    //            return
    //        }
    //
    //        console.context.globalObject.setValue(console, forProperty: "console")
    //        self.originalConsole = nil
    //    }

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
