//
//  WorkerLocation.swift
//  ServiceWorker
//
//  Created by alastair.coote on 25/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public class LocationBase: NSObject {

    fileprivate var components: URLComponents

    init?(withURL: URL) {
        guard let components = URLComponents(url: withURL, resolvingAgainstBaseURL: true) else {
            let err = JSValue(newErrorFromMessage: "Could not parse value provided", in: JSContext.current())
            JSContext.current().exception = err
            return nil
        }
        self.components = components
    }

    @objc public var href: String {
        get {
            return self.components.url?.absoluteString ?? ""
        }
        set(value) {
            do {
                guard let newURL = URL(string: value) else {
                    throw ErrorMessage("Could not parse value provided")
                }

                guard let components = URLComponents(url: newURL, resolvingAgainstBaseURL: true) else {
                    throw ErrorMessage("Could not create URL components")
                }

                self.components = components

            } catch {
                let err = JSValue(newErrorFromMessage: "\(error)", in: JSContext.current())
                JSContext.current().exception = err
                return
            }
        }
    }

    @objc(protocol) public var _protocol: String {
        get {

            if let scheme = components.scheme {
                return scheme + ":"
            } else {
                return ""
            }
        }
        set(value) {
            components.scheme = value
        }
    }

    @objc public var host: String {
        get {

            var host = self.hostname

            if let port = self.components.port {
                host += ":" + String(port)
            }

            return host
        }
        set(value) {

            guard let newComponents = URLComponents(string: value) else {
                return
            }

            self.hostname = newComponents.host ?? ""

            if let port = newComponents.port {
                self.port = String(port)
            }
        }
    }

    @objc public var hostname: String {
        get {
            return self.components.host ?? ""
        }
        set(value) {
            self.components.host = value
        }
    }

    @objc public var origin: String {
        get {
            return "\(self._protocol)//\(self.host)"
        }
        set(value) {
            // As observed in Chrome, this doesn't seem to do anything
        }
    }

    @objc public var port: String {
        get {
            if let portExists = self.components.port {
                return String(portExists)
            } else {
                return ""
            }
        }

        set(value) {
            if let portInt = Int(value) {
                self.components.port = portInt
            }
        }
    }

    @objc public var pathname: String {
        get {
            return self.components.path
        }
        set(value) {
            self.components.path = value
        }
    }

    @objc public var search: String {
        get {
            return self.components.query ?? ""
        }
        set(value) {
            self.components.query = value
        }
    }

    @objc public var _hash: String {
        get {
            if let fragment = self.components.fragment {
                return "#" + fragment
            } else {
                return ""
            }
        }
        set(value) {
            self.components.fragment = value
        }
    }

    internal static func getCurrentInstance<T: LocationBase>() -> (T, JSContext)? {

        guard let currentContext = JSContext.current() else {
            Log.error?("Somehow called URL hash getter outside of a JSContext. Should never happen")
            return nil
        }

        guard let this = JSContext.currentThis().toObjectOf(T.self) as? T else {

            currentContext.exception = currentContext
                .objectForKeyedSubscript("TypeError")
                .construct(withArguments: ["self type check failed for Objective-C instance method"])

            return nil
        }

        return (this, currentContext)
    }

    internal static let hashGetter: @convention(block) () -> JSValue? = {

        guard let current: (LocationBase, JSContext) = LocationBase.getCurrentInstance() else {
            return nil
        }

        return JSValue(object: current.0._hash, in: current.1)
    }
}
