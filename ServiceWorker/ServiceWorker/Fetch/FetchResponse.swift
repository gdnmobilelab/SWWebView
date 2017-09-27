import Foundation
import PromiseKit
import JavaScriptCore

@objc public class FetchResponse: NSObject {

    // We don't actually use this variable, but it ensures a strong reference
    // to the fetch task, which we depend upon while downloading. Once download
    // is complete, we remove this reference, allowing the task to be garbage
    // collected. We also pass it along when cloning responses.
    internal var fetchTask: FetchTask?

    public let headers: FetchHeaders
    public fileprivate(set) var status: Int

    public let url: URL?
    public let redirected: Bool

    internal var dataStream: WritableStreamProtocol = MemoryWriteStream()

    public var ok: Bool {
        return self.status >= 200 && self.status < 300
    }

    public let statusText: String

    convenience init(url: URL?, headers: FetchHeaders, status: Int, redirected: Bool) {
        self.init(url: url, headers: headers, status: status, statusText: HttpStatusCodes[status] ?? "Unknown", redirected: redirected)
    }

    init(url: URL?, headers: FetchHeaders, status: Int, statusText: String, redirected: Bool) {
        self.url = url
        self.status = status
        self.statusText = statusText
        self.headers = headers
        self.redirected = redirected
        super.init()
    }

    func clone() throws -> FetchResponse {

        guard let fetchTask = self.fetchTask else {
            throw ErrorMessage("Cannot clone response after task has been completed")
        }

        let clone = FetchResponse(url: url, headers: headers, status: status, redirected: redirected)
        clone.fetchTask = fetchTask
        fetchTask.add(response: clone)
        return clone
    }

    var downloadCompletionHandler: ((URLSession.ResponseDisposition) -> Void)?

    func receiveData(_ data: Data) {
        self.dataStream.enqueue(data)
    }

    public fileprivate(set) var bodyUsed: Bool = false

    fileprivate func markBodyUsed() throws {
        if self.bodyUsed == true {
            throw ErrorMessage("Body is already used")
        }
        self.bodyUsed = true
    }

    func streamEnded(withError _: Error? = nil) {
        self.dataStream.close()
    }

    func data() -> Promise<Data> {
        return firstly {
            try self.markBodyUsed()

            self.fetchTask?.beginDownloadIfNotAlreadyStarted()

            guard let memoryStream = self.dataStream as? MemoryWriteStream else {
                // shouldn't ever happen - markBodyUsed() would throw if this happened.
                throw ErrorMessage("The stream in this response has already been altered from a memory stream")
            }

            return memoryStream.allData
        }
    }

    public func fileDownload<T>(_ callback: @escaping (URL, Int64) throws -> Promise<T>) -> Promise<T> {

        return firstly {
            try self.markBodyUsed()
            let downloadPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("download")
            // add temporary file name

            // We now need to replace our stream with one that writes to disk, but also
            // grab any existing content in the memory stream, which can happen if the
            // response has been cloned.

            guard let existingStream = self.dataStream as? MemoryWriteStream else {
                throw ErrorMessage("Response stream has already been transformed")
            }

            guard let fileWriteStream = FileWriteStream(downloadPath) else {
                throw ErrorMessage("Could not create local file download stream")
            }

            self.dataStream.close()
            return existingStream.allData
                .then { dataSoFar -> Promise<T> in
                    fileWriteStream.enqueue(dataSoFar)
                    self.dataStream = fileWriteStream

                    self.fetchTask?.beginDownloadIfNotAlreadyStarted()

                    return fileWriteStream.withDownload(callback)
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
}
