import Foundation
import JavaScriptCore

/// Base class used by both JSURL and WorkerLocation (which have different JSExports, so
/// need to be different classes). Is basically a quick map between a URL object and
/// the JS API: https://developer.mozilla.org/en-US/docs/Web/API/URL
@objc public class LocationBase: NSObject {

    fileprivate var components: URLComponents
    @objc public let searchParams: URLSearchParams

    init?(withURL: URL) {
        guard let components = URLComponents(url: withURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        self.components = components
        self.searchParams = URLSearchParams(components: components)
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

    @objc public var `protocol`: String {
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
            return "\(self.protocol)//\(self.host)"
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

    internal static func getCurrentInstance<T: LocationBase>() -> T? {

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

        return this
    }

    fileprivate static let hashGetter: @convention(block) () -> String? = {
        guard let locationInstance = getCurrentInstance() else {
            return nil
        }

        return locationInstance._hash
    }

    fileprivate static let hashSetter: @convention(block) (String) -> Void = { value in
        guard let locationInstance = getCurrentInstance() else {
            return
        }
        locationInstance._hash = value
    }

    internal static func createJSValue(for context: JSContext) throws -> JSValue {

        guard let jsVal = JSValue(object: self, in: context) else {
            throw ErrorMessage("Could not create JSValue instance of class")
        }

        /// We can't use 'hash' as a property in native code because it's used by Objective C (grr)
        /// so we have to resort to this total hack to get hash back in JS environments.

        jsVal.objectForKeyedSubscript("prototype").defineProperty("hash", descriptor: [
            "get": unsafeBitCast(hashGetter, to: AnyObject.self),
            "set": unsafeBitCast(hashSetter, to: AnyObject.self)
        ])

        return jsVal
    }
}
