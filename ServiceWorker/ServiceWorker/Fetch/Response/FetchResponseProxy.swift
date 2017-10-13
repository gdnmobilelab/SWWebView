import Foundation
import JavaScriptCore
import PromiseKit

// Even without a specific Expose-Headers header, these are allowed on CORS responses:
private var allowedCORSHeaders = [
    "cache-control",
    "content-language",
    "content-type",
    "expires",
    "last-modified",
    "pragma"
]

/// This is the class actually exposed to worker environments. We wrap the actual FetchResponse because there are
/// a variety of response types: https://developer.mozilla.org/en-US/docs/Web/API/Response/type
/// this proxy takes these into account, exposes only the right data to JS, but also provides access to the internal
/// response natively, when we need to do things JS can't (like cache opaque responses)
@objc(Response) class FetchResponseProxy: NSObject, FetchResponseProtocol, FetchResponseJSExports, CacheableFetchResponse {

    var url: URL? {
        return self._internal.url
    }

    let responseType: ResponseType

    let _internal: FetchResponse

    init(from response: FetchResponse, type: ResponseType) {
        self.responseType = type
        self._internal = response
    }

    /// You can create a Response() in worker environments. Right now we only support constructing
    /// the body from a string or an ArrayBuffer, but should introduce more over time.
    required init?(body: JSValue, options: [String: Any]?) {
        self.responseType = .Default

        let headers = FetchHeaders()
        var status = 200
        var statusText = HttpStatusCodes[200] ?? "Unknown"

        // As outlined here: https://developer.mozilla.org/en-US/docs/Web/API/Response/Response
        // the Response constructor can have a few additional options specified upon creation.

        if let specifiedOptions = options {

            if let specifiedStatus = specifiedOptions["status"] as? Int {
                status = specifiedStatus
            }

            if let specifiedStatusText = specifiedOptions["statusText"] as? String {
                statusText = specifiedStatusText
            }

            if let specifiedHeaders = specifiedOptions["headers"] as? [String: String] {
                specifiedHeaders.forEach({ key, val in
                    headers.set(key, val)
                })
            }
        }

        if headers.get("Content-Type") == nil && body.isString {

            // This is what Chrome does. Not totally sure what the spec states.

            headers.set("Content-Type", "text/plain;charset=UTF-8")
        }

        // Even though our two response types aren't streams (they are already fully constructed data)
        // we turn them into streams to make them compatible with other FetchResponses. Also, in the future
        // we'll be able to add ReadableStream compatibility too.

        let inputStream = FetchResponseProxy.convert(jsValue: body)

        let streamPipe = StreamPipe(from: inputStream, bufferSize: 1024)

        // Feels a little silly, but our proxy constructor needs to create a FetchResponse, then proxy it.

        let constructedResponse = FetchResponse(url: nil, headers: headers, status: status, statusText: statusText, redirected: false, streamPipe: streamPipe)

        self._internal = constructedResponse
    }

    /// Right now this only supports strings and ArrayBuffers.
    fileprivate static func convert(jsValue val: JSValue) -> InputStream {
        do {
            if val.isString {

                guard let data = val.toString().data(using: String.Encoding.utf8) else {
                    throw ErrorMessage("Could not successfully parse string")
                }

                return InputStream(data: data)

            } else if let arrayBufferStream = InputStream(arrayBuffer: val) {

                return arrayBufferStream
            }

            throw ErrorMessage("Cannot convert input object")
        } catch {

            let err = JSValue(newErrorFromMessage: "\(error)", in: val.context)
            val.context.exception = err

            // Have to return something, although it'll never be used
            return InputStream(data: Data(count: 0))
        }
    }

    var streamPipe: StreamPipe? {
        return self._internal.streamPipe
    }

    var internalResponse: FetchResponse {
        return self._internal
    }

    func data() -> Promise<Data> {
        if self.responseType == .Opaque {
            return Promise(value: Data(count: 0))
        }
        return self._internal.data()
    }

    func json() -> Promise<Any?> {
        if self.responseType == .Opaque {
            return Promise(value: nil)
        }
        return self._internal.json()
    }

    func json() -> JSValue? {
        return self.json().toJSPromiseInCurrentContext()
    }

    func text() -> JSValue? {
        return self.text().toJSPromiseInCurrentContext()
    }

    func text() -> Promise<String> {

        if self.responseType == .Opaque {
            return Promise(value: "")
        }

        return self._internal.text()
    }

    func arrayBuffer() -> JSValue? {

        if self.responseType == .Opaque {

            return firstly { () -> Promise<JSValue> in

                Promise(value: JSArrayBuffer.make(from: Data(count: 0), in: JSContext.current()))

            }.toJSPromiseInCurrentContext()
        }

        return self.data()
            .then { data -> JSValue? in

                guard let currentContext = JSContext.current() else {
                    Log.error?("Tried to call arrayBuffer() outside of a JSContext")
                    return nil
                }

                let buffer = JSArrayBuffer.make(from: data, in: currentContext)
                return buffer
            }.toJSPromiseInCurrentContext()
    }

    func clone() throws -> FetchResponseProtocol {

        if self.bodyUsed {
            throw ErrorMessage("Cannot clone response: body already used")
        }

        let clonedInternalResponse = try self._internal.clone()

        return FetchResponseProxy(from: clonedInternalResponse, type: self.responseType)
    }

    func cloneResponseExports() -> FetchResponseJSExports? {

        // Really dumb but I can't figure out a better way to export both
        // clone() for Swift and clone() for JS because the Swift version
        // throws an error.

        var clone: FetchResponseJSExports?

        do {
            clone = try self.clone()
        } catch {

            var errmsg = String(describing: error)
            if let err = error as? ErrorMessage {
                errmsg = err.message
            }

            JSContext.current().exception = JSValue(newErrorFromMessage: errmsg, in: JSContext.current())
        }

        return clone
    }

    var headers: FetchHeaders {

        if self.responseType == .Opaque {
            return FetchHeaders()
        }

        if self.responseType == .CORS {

            var allowedHeaders = allowedCORSHeaders

            if let extraHeaders = self._internal.headers.get("Access-Control-Expose-Headers") {
                let extras = extraHeaders
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }

                allowedHeaders.append(contentsOf: extras)
            }

            return self._internal.headers.filteredBy(allowedKeys: allowedHeaders)

        } else if self.responseType == .Basic {

            return self._internal.headers.filteredBy(disallowedKeys: ["set-cookie", "set-cookie2"])

        } else {
            return self._internal.headers
        }
    }

    var statusText: String {

        if self.responseType == .Opaque {
            return ""
        }

        return self._internal.statusText
    }

    var ok: Bool {

        if self.responseType == .Opaque {
            // This is what Chrome does. Not entirely sure what the spec says.
            return false
        }

        return self._internal.ok
    }

    var redirected: Bool {

        if self.responseType == .Opaque {
            // This is what Chrome does. Not entirely sure what the spec says.
            return false
        }

        return self._internal.redirected
    }

    var bodyUsed: Bool {
        return self._internal.bodyUsed
    }

    var status: Int {

        if self.responseType == .Opaque {
            return 0
        }

        return self._internal.status
    }

    var responseTypeString: String {
        return self.responseType.rawValue
    }

    var urlString: String {
        if self.responseType == .Opaque {
            return ""
        }
        return self.url?.absoluteString ?? ""
    }
}
