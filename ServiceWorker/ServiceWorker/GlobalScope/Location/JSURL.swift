import Foundation
import JavaScriptCore

@objc public protocol JSURLExports: JSExport {
    var href: String { get set }
    var `protocol`: String { get set }
    var host: String { get set }
    var hostname: String { get set }
    var origin: String { get set }
    var port: String { get set }
    var pathname: String { get set }
    var search: String { get set }
    var searchParams: URLSearchParams { get }

    init?(url: JSValue, relativeTo: JSValue)
}

/// An implementation of the JS URL object: https://developer.mozilla.org/en-US/docs/Web/API/URL
@objc public class JSURL: LocationBase, JSURLExports {

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
}
