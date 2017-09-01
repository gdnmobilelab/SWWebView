//
//  Location.swift
//  ServiceWorker
//
//  Created by alastair.coote on 25/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol JSURLExports: JSExport {
    var href: String { get set }

    @objc(protocol)
    var _protocol: String { get set }

    var host: String { get set }
    var hostname: String { get set }
    var origin: String { get set }
    var port: String { get set }
    var pathname: String { get set }
    var search: String { get set }

    init?(url: JSValue, relativeTo: JSValue)
}

@objc(JSURL) public class JSURL: LocationBase, JSURLExports {

    public required init?(url: JSValue, relativeTo: JSValue) {

        do {

            var parsedRelative: URL?

            if relativeTo.isUndefined == false {
                guard let relative = URL(string: relativeTo.toString()), relative.host != nil, relative.scheme != nil else {
                    throw ErrorMessage("Invalid base URL")
                }
                parsedRelative = relative
            }

            guard let parsedURL = URL(string: url.toString(), relativeTo: parsedRelative), parsedURL.host != nil, parsedURL.scheme != nil else {
                throw ErrorMessage("Invalid URL")
            }

            super.init(withURL: parsedURL)

        } catch {
            let err = JSValue(newErrorFromMessage: "\(error)", in: url.context)
            url.context.exception = err
            return nil
        }
    }

    fileprivate static let hashSetter: @convention(block) (JSValue) -> Void = { newValue in

        if newValue.isString {

            guard let current: (JSURL, JSContext) = JSURL.getCurrentInstance() else {
                return
            }

            current.0._hash = newValue.toString()
        }
    }

    /// We can't use 'hash' as a property in native code because it's used by Objective C (grr)
    /// so we have to resort to this total hack to get hash back.
    static func addToWorkerContext(context: JSContext) {

        context.globalObject.setValue(JSURL.self, forProperty: "URL")
        let jsInstance = context.globalObject.objectForKeyedSubscript("URL")!

        // Also add it to the self object
        context.globalObject.objectForKeyedSubscript("self")
            .setValue(jsInstance, forProperty: "URL")

        // Now graft in our awful hacks to get and set hash
        context.objectForKeyedSubscript("Object")
            .objectForKeyedSubscript("defineProperty")
            .call(withArguments: [jsInstance.objectForKeyedSubscript("prototype"), "hash", [
                "get": unsafeBitCast(self.hashGetter, to: AnyObject.self),
                "set": unsafeBitCast(self.hashSetter, to: AnyObject.self)
            ]])
    }
}
