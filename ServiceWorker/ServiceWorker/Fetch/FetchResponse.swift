import Foundation
import PromiseKit
import JavaScriptCore

@objc public class FetchResponse: NSObject {

    internal var streamPipe: StreamPipe?

    public let headers: FetchHeaders
    public fileprivate(set) var status: Int

    public let url: URL?
    public let redirected: Bool

    public var ok: Bool {
        return self.status >= 200 && self.status < 300
    }

    public let statusText: String

    public convenience init(url: URL?, headers: FetchHeaders, status: Int, redirected: Bool, streamPipe: StreamPipe) {
        self.init(url: url, headers: headers, status: status, statusText: HttpStatusCodes[status] ?? "Unknown", redirected: redirected, streamPipe: streamPipe)
    }

    public init(url: URL?, headers: FetchHeaders, status: Int, statusText: String, redirected: Bool, streamPipe: StreamPipe) {
        self.url = url
        self.status = status
        self.statusText = statusText
        self.headers = headers
        self.redirected = redirected
        self.streamPipe = streamPipe
        super.init()
    }

    func clone() throws -> FetchResponse {

        guard let streamPipe = self.streamPipe else {
            throw ErrorMessage("Cannot clone response after stream has been removed")
        }

        // Because we can call the actions on this response at any point, we need to create an
        // in-memory buffer that'll store data temporarily, if the original response
        // starts earlier.

        let (passthroughInput, passthroughOutput) = PassthroughStream.create()
        try streamPipe.add(stream: passthroughOutput)

        let newStreamPipe = StreamPipe(from: passthroughInput, bufferSize: streamPipe.bufferSize)

        let clone = FetchResponse(url: url, headers: headers, status: status, redirected: redirected, streamPipe: newStreamPipe)
        return clone
    }

    var downloadCompletionHandler: ((URLSession.ResponseDisposition) -> Void)?

    //    func receiveData(_ data: Data) {
    //        self.dataStream.enqueue(data)
    //    }

    public fileprivate(set) var bodyUsed: Bool = false

    fileprivate func markBodyUsed() throws {
        if self.bodyUsed == true {
            throw ErrorMessage("Body is already used")
        }
        self.bodyUsed = true
    }

    //    func streamEnded(withError _: Error? = nil) {
    //        self.dataStream.close()
    //    }

    func data() -> Promise<Data> {
        return firstly {
            try self.markBodyUsed()

            let memoryStream = OutputStream.toMemory()

            guard let streamPipe = self.streamPipe else {
                throw ErrorMessage("Reference to stream pipe has been removed, can't act on data")
            }

            try streamPipe.add(stream: memoryStream)

            return streamPipe.pipe()
                .then { () -> Data in

                    guard let data = memoryStream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data else {
                        throw ErrorMessage("Could not fetch in-memory data from stream")
                    }

                    return data
                }
        }
    }

    public func fileDownload<T>(_ callback: @escaping (URL, Int64) throws -> Promise<T>) -> Promise<T> {

        return firstly {
            try self.markBodyUsed()
            let downloadPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("download")
            // add temporary file name

            guard let streamPipe = self.streamPipe else {
                throw ErrorMessage("Reference to StreamPipe has been removed, cannot turn into download")
            }

            guard let fileStream = OutputStream(url: downloadPath, append: false) else {
                throw ErrorMessage("Could not create local file stream")
            }

            try streamPipe.add(stream: fileStream)

            return streamPipe.pipe()
                .then { () -> Promise<T> in
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: downloadPath.path)
                    guard let size = fileAttributes[.size] as? Int64 else {
                        throw ErrorMessage("Could not get size of downloaded file")
                    }

                    return try callback(downloadPath, size)
                }
                .then { result -> T in
                    try FileManager.default.removeItem(at: downloadPath)
                    return result
                }
        }
    }

    func json() -> Promise<Any?> {
        return self.data()
            .then { data -> Any in
                try JSONSerialization.jsonObject(with: data, options: [])
            }
    }

    func json() -> JSValue? {
        return self.json().toJSPromise(in: JSContext.current())
    }

    fileprivate static func guessCharsetFrom(headers: FetchHeaders) -> String.Encoding {

        var charset = String.Encoding.utf8

        if let contentTypeHeader = headers.get("Content-Type") {
            do {
                let charsetRegex = try NSRegularExpression(pattern: ";\\s?charset=(.*)+", options: [])
                let charsetMatches = charsetRegex.matches(in: contentTypeHeader, options: [], range: NSRange(location: 0, length: contentTypeHeader.characters.count))

                if let relevantMatch = charsetMatches.first {

                    let matchText = (contentTypeHeader as NSString).substring(with: relevantMatch.range).lowercased()

                    if matchText == "utf-16" {
                        charset = String.Encoding.utf16
                    } else if matchText == "utf-32" {
                        charset = String.Encoding.utf32
                    } else if matchText == "iso-8859-1" {
                        charset = String.Encoding.windowsCP1252
                    }
                }
            } catch {
                Log.warn?("Couldn't parse charset: \(contentTypeHeader)")
            }
        }

        return charset
    }

    public func text() -> Promise<String> {

        let encoding = FetchResponse.guessCharsetFrom(headers: headers)

        return self.data()
            .then { data -> String in
                guard let str = String(data: data, encoding: encoding) else {
                    throw ErrorMessage("Could not decode string content")
                }
                return str
            }
    }

    func text() -> JSValue? {
        return self.text().toJSPromise(in: JSContext.current())
    }

    internal func arrayBuffer() -> JSValue? {

        guard let currentContext = JSContext.current() else {
            Log.error?("Tried to call arrayBuffer() outside of a JSContext")
            return nil
        }

        return self.data()
            .then { data -> JSValue in
                JSArrayBuffer.make(from: data, in: currentContext)
            }
            .toJSPromise(in: currentContext)
    }

    func getReader() throws -> ReadableStream {
        return ReadableStream()
    }

    public func getWrappedVersion(for type: ResponseType, corsAllowedHeaders: [String]? = nil) throws -> FetchResponseProtocol {

        if type == .Basic {
            return try BasicResponse(from: self)
        } else if type == .Opaque {
            return try OpaqueResponse(from: self)
        } else if type == .CORS {
            return try CORSResponse(from: self, allowedHeaders: corsAllowedHeaders)
        }

        throw ErrorMessage("Cannot create protocol for this response type")
    }
}
