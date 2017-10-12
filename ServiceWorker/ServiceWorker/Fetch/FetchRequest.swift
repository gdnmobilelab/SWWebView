import Foundation
import JavaScriptCore

/// https://developer.mozilla.org/en-US/docs/Web/API/Request/redirect
public enum FetchRequestRedirect: String {
    case Follow = "follow"
    case Error = "error"
    case Manual = "manual"
}

/// Partial implementation: https://developer.mozilla.org/en-US/docs/Web/API/Request/cache
/// there are a lot more options on the MDN page than we have here.
public enum FetchRequestCache: String {
    case Default = "default"
    case Reload = "reload"
    case NoCache = "no-cache"
}

/// https://developer.mozilla.org/en-US/docs/Web/API/Request/mode
/// excludes the "navigate" mode, doesn't really apply to what we're doing here
public enum FetchRequestMode: String {
    case SameOrigin = "same-origin"
    case NoCORS = "no-cors"
    case CORS = "cors"
}

@objc protocol FetchRequestExports: JSExport {
    var method: String { get }

    // This is slightly confusing, but FetchRequest's URL property is a URL in Swift, and a String
    // in the JS environment. As a side-effect, also in Objective C.
    @objc(url)
    var urlString: String { get }

    @objc(referrer)
    var referrerString: String? { get }

    @objc(mode)
    var modeString: String { get }

    var headers: FetchHeaders { get }
    var referrerPolicy: String? { get }

    @objc(redirect)
    var redirectString: String { get }

    init?(url: JSValue, options: JSValue)
}

/// Replicating the Request API: https://developer.mozilla.org/en-US/docs/Web/API/Request/Request
@objc public class FetchRequest: NSObject, FetchRequestExports {
    public var method: String = "GET"
    public let url: URL
    public var headers: FetchHeaders
    public var referrer: URL?
    public var referrerPolicy: String?
    public var mode: FetchRequestMode = .CORS
    public var redirect: FetchRequestRedirect = FetchRequestRedirect.Follow
    public var cache: FetchRequestCache = FetchRequestCache.Default
    public var body: Data?

    public var urlString: String {
        return self.url.absoluteString
    }

    public var referrerString: String? {
        return self.referrer?.absoluteString
    }

    public var redirectString: String {
        return self.redirect.rawValue
    }

    public var modeString: String {
        return self.mode.rawValue
    }

    public init(url: URL) {
        self.url = url
        self.headers = FetchHeaders()
        super.init()
    }

    public func clone() -> FetchRequest {

        let request = FetchRequest(url: self.url)
        request.method = self.method
        request.body = self.body
        request.cache = self.cache
        request.headers = self.headers.clone()
        request.mode = self.mode
        request.redirect = self.redirect
        request.referrer = self.referrer

        return request
    }

    public required convenience init?(url: JSValue, options: JSValue) {
        do {

            if url.isString == false {
                throw ErrorMessage("Must provide a string URL")
            }

            // In JS we can pass in relative string URLs. So we need to get our execution environment
            // , and from that the worker URL. Then we create our native, absolute URL.

            guard let exec = ServiceWorkerExecutionEnvironment.contexts.object(forKey: JSContext.current()) else {
                throw ErrorMessage("Initialiser must be run inside a service worker")
            }

            guard let absoluteURL = URL(string: url.toString(), relativeTo: exec.worker.url) else {
                throw ErrorMessage("Could not create relative URL with string provided")
            }

            // URL.standardized means we lose any /root/../back stuff and get a fully resolved URL

            self.init(url: absoluteURL.standardized.absoluteURL)
            if let optionsObject = options.toObject() as? [String: AnyObject] {
                try self.applyOptions(opts: optionsObject)
            }

        } catch {
            let error = JSValue(newErrorFromMessage: "\(error)", in: options.context)
            options.context.exception = error
            return nil
        }
    }

    /// Request.options.headers can either be an instance of Headers or a key-value object.
    /// We need to handle both types here.
    internal func applyHeadersIfExist(opts: [String: AnyObject]) {
        if let headers = opts["headers"] as? FetchHeaders {
            self.headers = headers
        } else if let headers = opts["headers"] as? [String: String] {

            let headersInstance = FetchHeaders()

            for (key, val) in headers {
                headersInstance.append(key, val)
            }

            self.headers = headersInstance
        }
    }

    internal func applyOptions(opts: [String: AnyObject]) throws {

        if let method = opts["method"] as? String {
            self.method = method
        }

        self.applyHeadersIfExist(opts: opts)

        if let body = opts["body"] as? String {
            if self.method == "GET" || self.method == "HEAD" {
                throw ErrorMessage("Cannot send a body with a \(self.method) request")
            }
            self.body = body.data(using: String.Encoding.utf8)
        } else if opts["body"] != nil {
            throw ErrorMessage("Can only support string request bodies at the moment")
        }

        if let mode = opts["mode"] as? String {
            guard let modeVal = FetchRequestMode(rawValue: mode) else {
                throw ErrorMessage("Did not understand value for attribute 'mode'")
            }
            self.mode = modeVal
        }

        if let cache = opts["cache"] as? String {
            guard let cacheVal = FetchRequestCache(rawValue: cache) else {
                throw ErrorMessage("Did not understand value for attribute 'cache'")
            }
            self.cache = cacheVal
        }

        if let redirect = opts["redirect"] as? String {

            guard let redirectVal = FetchRequestRedirect(rawValue: redirect) else {
                throw ErrorMessage("Did not understand value for attribute 'redirect'")
            }

            self.redirect = redirectVal
        }
    }

    /// Turn this into a native URLRequest that we can use with URLSession. We could probably
    /// actually have FetchRequest inherit from URLRequest instead of doing this, but oh well.
    internal func toURLRequest() -> URLRequest {

        var cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
        if self.cache == FetchRequestCache.NoCache {
            cachePolicy = .reloadIgnoringLocalCacheData
        } else if self.cache == .Reload {
            cachePolicy = .reloadRevalidatingCacheData
        }

        if self.redirect == .Manual {
            // For some reason the combination of not following redirects and using caches will break.
            // Appears to be this: http://www.openradar.me/31284156
            cachePolicy = .reloadIgnoringLocalCacheData
        }

        var nsRequest = URLRequest(url: self.url, cachePolicy: cachePolicy, timeoutInterval: 60)

        nsRequest.httpMethod = self.method

        self.headers.values.forEach { keyvalPair in
            nsRequest.addValue(keyvalPair.value, forHTTPHeaderField: keyvalPair.key)
        }

        if let body = self.body {
            nsRequest.httpBody = body
        }

        return nsRequest
    }
}
