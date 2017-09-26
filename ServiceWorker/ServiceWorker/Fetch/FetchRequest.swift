import Foundation
import JavaScriptCore

public enum FetchRequestRedirect: String {
    case Follow = "follow"
    case Error = "error"
    case Manual = "manual"
}

public enum FetchRequestCache: String {
    case Default = "default"
    case Reload = "reload"
    case NoCache = "no-cache"
}

public enum FetchRequestMode: String {
    case SameOrigin = "same-origin"
    case NoCORS = "no-cors"
    case CORS = "cors"
}

@objc protocol FetchRequestExports: JSExport {
    var method: String { get }

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

    //    internal var origin: URL?

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

    public required convenience init?(url: JSValue, options: JSValue) {
        do {

            if url.isString == false {
                throw ErrorMessage("Must provide a string URL")
            }

            guard let workerLocation = options.context.globalObject.objectForKeyedSubscript("location").toObjectOf(WorkerLocation.self) as? WorkerLocation else {
                // It's possible to call this constructor outside of a service worker scope, but we don't
                // want to allow that, because we need to resolve relative URLs. If there is no self.scriptURL
                // we must not be in a worker, so we fail.

                throw ErrorMessage("Request must be used inside a Service Worker context")
            }

            guard let parsedScriptURL = URL(string: workerLocation.href) else {
                throw ErrorMessage("Could not parse the worker context's script URL successfully")
            }

            guard let relativeURL = URL(string: url.toString(), relativeTo: parsedScriptURL) else {
                throw ErrorMessage("Could not create relative URL with string provided")
            }
            self.init(url: relativeURL.standardized.absoluteURL)
            if let optionsObject = options.toObject() as? [String: AnyObject] {
                try self.applyOptions(opts: optionsObject)
            }

        } catch {
            let error = JSValue(newErrorFromMessage: "\(error)", in: options.context)
            options.context.exception = error
            return nil
        }
    }

    /// The Fetch API has various rules regarding the origin of requests. We try to respect
    /// that as best we can.
    //    internal func enforceOrigin(origin: URL) throws {
    //        self.origin = origin
    //
    //        if self.mode == .SameOrigin {
    //            if self.url.scheme != origin.scheme || self.url.host != origin.host {
    //                throw ErrorMessage("URL is not valid for a same-origin request")
    //            }
    //        } else if self.mode == .NoCORS {
    //            if self.method != "HEAD" && self.method != "GET" && self.method != "POST" {
    //                throw ErrorMessage("Can only send HEAD, GET and POST requests with no-cors requests")
    //            }
    //        }
    //    }

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
