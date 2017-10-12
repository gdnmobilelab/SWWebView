import Foundation
import PromiseKit
import JavaScriptCore

/// This represents a download from FetchSession. It is created as soon as status, headers etc are received,
/// and contains promise methods to transform incoming data into a variety of formats. It's modelled on the
/// Response object on the web, but our worker environments actually use FetchResponseProxy in that context.
@objc public class FetchResponse: NSObject {

    /// The incoming data. In FetchSession it's assigned in a delegate method, but this could also
    /// be assigned as the result of response.clone(), or new Response()
    internal var streamPipe: StreamPipe?

    public let headers: FetchHeaders
    public fileprivate(set) var status: Int

    public let url: URL?

    /// Whether the response was redirected before returning the data it now has
    public let redirected: Bool

    public var ok: Bool {
        return self.status >= 200 && self.status < 300
    }

    public let statusText: String

    /// The most commonly used initialiser.
    public convenience init(url: URL?, headers: FetchHeaders, status: Int, redirected: Bool, streamPipe: StreamPipe) {
        self.init(url: url, headers: headers, status: status, statusText: HttpStatusCodes[status] ?? "Unknown", redirected: redirected, streamPipe: streamPipe)
    }

    /// The underlying initialiser. Only difference with the commonly used one is that we can specify statusText - normally they are
    /// tied directly to the status code, but the Response API in JS lets you specify your own custom status text. Not sure why,
    /// but we mirror that same behaviour here.
    public init(url: URL?, headers: FetchHeaders, status: Int, statusText: String, redirected: Bool, streamPipe: StreamPipe) {
        self.url = url
        self.status = status
        self.statusText = statusText
        self.headers = headers
        self.redirected = redirected
        self.streamPipe = streamPipe
        super.init()
    }

    /// Based on this: https://developer.mozilla.org/en-US/docs/Web/API/Response/clone, it allows us to process
    /// the data in a response more than once - for instance, to send one copy to the cache and the other to
    /// text()
    func clone() throws -> FetchResponse {

        guard let streamPipe = self.streamPipe else {
            throw ErrorMessage("Cannot clone response after stream has been removed")
        }

        if self.bodyUsed {
            throw ErrorMessage("Cannot clone after we've already started downloading")
        }

        // Once we've cloned a response, we can call a transformer (text(), data() etc) at any point,
        // so the clone might need to process the data at a different time than the original response.
        // To facilitate this, we use PassthroughStream to create an in-memory buffer that stores any
        // unprocessed data before a transformer is called.

        // POSSIBLE BUG: does the clone rely on the original response transformer being called before
        // it does anything? I think it might. Need to write some tests and work out a solution for that.

        let (passthroughInput, passthroughOutput) = PassthroughStream.create()
        try streamPipe.add(stream: passthroughOutput)

        let newStreamPipe = StreamPipe(from: passthroughInput, bufferSize: streamPipe.bufferSize)

        let clone = FetchResponse(url: url, headers: headers, status: status, redirected: redirected, streamPipe: newStreamPipe)
        return clone
    }

    /// Because our data is a linear stream, once we've started downloading we can't use it again. We use this
    /// attribute to keep track of when we have, to shut off future data() and clone() use.
    public fileprivate(set) var bodyUsed: Bool = false

    fileprivate func markBodyUsed() throws {
        if self.bodyUsed == true {
            throw ErrorMessage("Body is already used")
        }
        self.bodyUsed = true
    }

    /// Pipes the incoming stream directly into memory, then returns the Data object. Most other transformers
    /// chain off this to do whatever they need to with the data. Not in the web API spec, but is roughly
    /// a mirror of arrayBuffer()
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

    /// Another non-spec addition. Because we don't know the length of responses (might not have a Content-Length header,
    /// or it might be wrong depending on compression), we sometimes need to save a response to disk before further
    /// processing (primarily for streaming into SQLite blobs, which need to have a size predefined).
    ///
    /// Once we have downloaded the file, we call the callback, which resolves to a promise. Once that promise is resolved
    /// (that is, we can do something asynchronous) we delete the temporarily stored file.
    public func fileDownload<T>(_ callback: @escaping (URL, Int64) throws -> Promise<T>) -> Promise<T> {

        // The resulting type of this promise is dictated by the object returned by the inner callback.
        // The idea being that the code using fileDownload() can relatively seamlessly pass a result back
        // into the main promise chain without worrying about manually deleting the temp file.

        return firstly {
            try self.markBodyUsed()

            guard let streamPipe = self.streamPipe else {
                throw ErrorMessage("Reference to StreamPipe has been removed, cannot turn into download")
            }

            // We store the files in NSTemporaryDirectory(). There might be better places for that, I'm
            // not sure.

            let downloadPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                // We're just using a randomised UUID here. Are there better alternatives?
                .appendingPathComponent(UUID().uuidString)
                // Then appending .download to the end of it, because why not.
                .appendingPathExtension("download")

            // Foundation has a built-in stream for writing to a local file, so we use that to pipe
            // out download stream into it.

            guard let fileStream = OutputStream(url: downloadPath, append: false) else {
                throw ErrorMessage("Could not create local file stream")
            }

            try streamPipe.add(stream: fileStream)
            return streamPipe.pipe()
                .then { () -> Promise<T> in

                    // Since the main reason for using fileDownload() is to get the size of the file,
                    // we're doing so here to save replicating the code everywhere.

                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: downloadPath.path)
                    guard let size = fileAttributes[.size] as? Int64 else {
                        throw ErrorMessage("Could not get size of downloaded file")
                    }

                    // Callback is a generic function that allows us to return whatever we want, which is then
                    // passed on to be the result of this promise chain.

                    return try callback(downloadPath, size)
                }
                .always {

                    // Now that our promise has been resolved (successfully or not)
                    // we can delete the temporary file we just downloaded.

                    do {
                        try FileManager.default.removeItem(at: downloadPath)
                    } catch {
                        Log.error?("Could not delete temporary fetch file at \(downloadPath.path)")
                    }
                }
        }
    }

    /// Pretty much what you'd expect. Uses JSONSerialization to turn the data into
    /// a Dictionary, Array, nil, or whatever the JSON represents.
    func json() -> Promise<Any?> {

        return self.data()
            .then { data in
                try JSONSerialization.jsonObject(with: data, options: [])
            }
    }

    /// There might be a native way of doing this that I'm not aware of, but when using text() we need
    /// to know what charset to decode with. We default to UTF8, but if the Content-Type header specifies
    /// a different charset, we use that instead.
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

    /// Transform the stream data into text.
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

    /// FetchResponseProxy isn't actually a public class, while FetchResponse is. Might want to rethink that,
    /// but for now, this allows code outside of ServiceWorker (like, Cache API code) to construct different
    /// response types.
    public func getWrappedVersion(for type: ResponseType) throws -> FetchResponseProtocol {
        return FetchResponseProxy(from: self, type: type)
    }
}
