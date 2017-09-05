//
//  FetchResponse.swift
//  ServiceWorker
//
//  Created by alastair.coote on 13/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc public class FetchResponse: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {

    internal var fetchOperation: FetchOperation?
    internal var responseCallback: ((URLSession.ResponseDisposition) -> Void)?

    public let headers: FetchHeaders
    public var bodyUsed: Bool = false
    internal var dataStream: ReadableStream
    fileprivate var streamController: ReadableStreamController

    public init(headers: FetchHeaders, status: Int, url: URL, redirected: Bool, fetchOperation: FetchOperation?, stream: ReadableStream? = nil) throws {
        self.fetchOperation = fetchOperation
        self.responseCallback = nil
        self.headers = headers
        self.status = status
        self.url = url
        self.redirected = redirected

        if let str = stream {
            // We can override the underlying stream if we want - this is used
            // in OpaqueResponse to ensure we don't actually provide the response
            // body
            self.dataStream = str
            self.streamController = str.controller
        } else {
            // Otherwise we create another new stream and hook up the fetch
            // operation.

            self.dataStream = ReadableStream()
            self.streamController = self.dataStream.controller
        }
        super.init()

        if stream == nil {
            // if we've created a new stream (as above) we now need to add ourselves as a delegate.
            if let op = fetchOperation {
                op.add(delegate: self)
            }
        }
    }

    init(response: HTTPURLResponse, operation: FetchOperation, callback: @escaping (URLSession.ResponseDisposition) -> Void) throws {
        self.fetchOperation = operation
        self.responseCallback = callback
        self.status = response.statusCode
        guard let url = response.url else {
            throw ErrorMessage("Response has no URL")
        }
        self.url = url
        self.redirected = operation.redirected

        guard let task = operation.task else {
            throw ErrorMessage("Incoming fetch operation has no task")
        }

        // Convert to our custom FetchHeaders class
        let headers = FetchHeaders()
        response.allHeaderFields.keys.forEach { key in

            guard let keyString = key as? String, let value = response.allHeaderFields[key] as? String else {
                Log.error?("Received a non-string key/value header pair?")
                return
            }

            if keyString.lowercased() == "content-encoding" {
                // URLSession automatically decodes content (which we don't actually want it to do)
                // so the only way to continue to use this is to strip out the Content-Encoding
                // header, otherwise the browser will try to decode it again
                return
            } else if keyString.lowercased() == "content-length" {
                // Because of this same GZIP issue, the content length will be incorrect. It's actually
                // also normally incorrect, but because we're stripping out all encoding we should
                // update the content-length header to be accurate.
                headers.set("Content-Length", String(task.countOfBytesExpectedToReceive))
                return
            }

            headers.set(keyString, value)
        }

        self.headers = headers

        dataStream = ReadableStream()
        self.streamController = dataStream.controller
        super.init()

        // since this is being created directly from native, we know we want
        // it to be a delegate
        operation.add(delegate: self)
    }

    public var internalResponse: FetchResponse {
        return self
    }

    public var responseType: ResponseType {
        return .Internal
    }

    public var responseTypeString: String {
        return self.responseType.rawValue
    }

    public var urlString: String {
        return self.url.absoluteString
    }

    public let url: URL
    public let status: Int
    public let redirected: Bool

    public var ok: Bool {
        return self.status >= 200 && self.status < 300
    }

    public var statusText: String {

        if let status = HttpStatusCodes[self.status] {
            return status
        }
        return "Unassigned"
    }

    fileprivate func markBodyUsed() throws {
        if self.bodyUsed == true {
            throw ErrorMessage("Body was already used")
        }
        self.bodyUsed = true
    }

    public func getReader() throws -> ReadableStream {
        try self.markBodyUsed()
        if let responseCallback = self.internalResponse.responseCallback {
            responseCallback(.allow)
            // This can only be run once, so once we've done that, clear it out.
            self.internalResponse.responseCallback = nil
        }

        return self.dataStream
    }

    public func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {

        do {
            try self.streamController.enqueue(data)
        } catch {
            Log.error?("Failed to enqueue data:")
        }
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
        do {
            try self.streamController.close()
        } catch {
            Log.error?("Failed to close stream controller")
        }
    }

    public func data() -> Promise<Data> {

        return firstly {
            let reader = try self.getReader()

            return reader.readAll()
        }
    }

    fileprivate var fileDownloadComplete: ((URL) -> Promise<Void>)?

    public func fileDownload<T>(withDownload: @escaping (URL) throws -> Promise<T>) -> Promise<T> {

        return firstly {
            try self.markBodyUsed()
            if let responseCallback = self.internalResponse.responseCallback {
                responseCallback(.becomeDownload)
                // This can only be run once, so once we've done that, clear it out.
                self.internalResponse.responseCallback = nil
            } else {
                throw ErrorMessage("Response callback already set")
            }

            return Promise<T> { fulfill, reject in

                self.fileDownloadComplete = { url in

                    firstly {
                        return try withDownload(url)
                    }
                    .then { response in
                        fulfill(response)
                    }
                    .recover { error in
                        reject(error)
                    }
                }
            }
        }
    }

    public func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        // Because this needs to be run synchronously, we freeze the current (background) thread
        // and process our callback promise. Then resume the thread.

        guard let downloadComplete = self.fileDownloadComplete else {
            Log.error?("Download complete callback called but we have no handler for it. Should never happen")
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .background).async {

            downloadComplete(location)
                .always {
                    semaphore.signal()
                }
        }

        semaphore.wait()
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

    public func json() -> Promise<Any?> {
        return self.data()
            .then { data -> Any in
                try JSONSerialization.jsonObject(with: data, options: [])
            }
    }

    public func getContentLength() throws -> Int64? {
        if let lengthHeader = self.headers.get("Content-Length") {
            if let lengthIsANumber = Int64(lengthHeader) {
                return lengthIsANumber
            } else {
                throw ErrorMessage("Content-Length header must be a number")
            }
        } else {
            return nil
        }
    }

    public static func guessCharsetFrom(headers: FetchHeaders) -> String.Encoding {

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

    func json() -> JSValue? {

        return self.json().toJSPromise(in: JSContext.current())
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

                //                var mutableData: Data = data
                //
                //                let arr = mutableData.withUnsafeMutableBytes { pointer -> JSObjectRef in
                //                    return JSObjectMakeArrayBufferWithBytesNoCopy(currentContext.jsGlobalContextRef, pointer, data.count, { _, _ in
                //                        // TODO: WTF to do with this
                //
                //                        NSLog("Deallocate data!")
                //                    }, &mutableData, nil)
                //                }

                //                let test = Test(data: data, context: currentContext)
                //                let arr = JSObjectMakeArrayBufferWithBytesNoCopy(currentContext.jsGlobalContextRef, test.data.mutableBytes, test.data.length, { _, _ in
                //                    NSLog("done?")
                //                }, nil, nil)
                //                let js = JSValue(jsValueRef: arr, in: currentContext)

                //                Test.map.setObject(test, forKey: js)

                //                let val = JSValue(jsValueRef: test, in: currentContext)!
                //                currentContext.virtualMachine.addManagedReference(test, withOwner: test.jsVal)
                //                return js!
            }
            //            .toJSPromise(in: currentContext)
            .toJSPromise(in: currentContext)
    }

    //    public func json(_ callback: @escaping (Error?, Any?) -> Void) {
    //
    //        self.data { err, data in
    //
    //            if err != nil {
    //                callback(err, nil)
    //                return
    //            }
    //
    //            do {
    //                let json = try JSONSerialization.jsonObject(with: data!, options: [])
    //                callback(nil, json)
    //            } catch {
    //                callback(error, nil)
    //            }
    //        }
    //    }

    deinit {

        if let operation = self.fetchOperation {
            if let task = operation.task {
                Log.warn?("Terminating currently pending fetch operation for: " + operation.request.url.absoluteString)
                task.cancel()
            }
        }
    }
}
