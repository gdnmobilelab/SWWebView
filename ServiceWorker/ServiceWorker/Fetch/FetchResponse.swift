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

@objc public class FetchResponse: NSObject, URLSessionDataDelegate {

    internal var fetchOperation: FetchOperation?
    internal var responseCallback: ((URLSession.ResponseDisposition) -> Void)?

    public let headers: FetchHeaders
    public var bodyUsed: Bool = false
    internal var dataStream: ReadableStream?
    fileprivate var streamController: ReadableStreamController?

    /// We use this context when using the JS-type functions, like json() etc
    /// to create JSPromises
    internal var jsContext: JSContext?

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

        if HttpStatusCodes[self.status] != nil {
            return HttpStatusCodes[self.status]!
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
        return self.dataStream!
    }

    public func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {

        do {
            try self.streamController!.enqueue(data)
        } catch {
            Log.error?("Failed to enqueue data:")
        }
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
        self.streamController!.close()
    }

    public func data() -> Promise<Data> {

        return firstly {
            let reader = try self.getReader()

            var allData = Data()

            // Annoying but I can't find any other way to get around Swift complaining
            // about “Variable used within its own initial value”
            return Promise { fulfill, _ in
                var doRead: (() -> Void)?
                doRead = {
                    reader.read { read in
                        if read.done {
                            fulfill(allData)
                        } else {
                            allData.append(read.value!)
                            doRead!()
                        }
                    }
                }

                doRead!()
            }
        }
    }

    internal func data(_ callback: @escaping (Error?, Data?) -> Void) {

        var reader: ReadableStream

        do {
            reader = try self.getReader()
        } catch {
            callback(error, nil)
            return
        }

        var allData = Data()

        // Annoying but I can't find any other way to get around Swift complaining
        // about “Variable used within its own initial value”

        var doRead: (() -> Void)?
        doRead = {
            reader.read { read in
                if read.done {
                    callback(nil, allData)
                } else {
                    allData.append(read.value!)
                    doRead!()
                }
            }
        }

        doRead!()
    }

    public func text() -> Promise<String> {

        let encoding = FetchResponse.guessCharsetFrom(headers: headers)

        return self.data()
            .then { data -> String in
                let str = String(data: data, encoding: encoding)!
                return str
            }

        //        return firstly {
        //            Promise(value: try self.getReader())
        //        }
        //        .then { reader in
        //
        //            var str = ""
        //
        //            return reader.readToEnd(transformer: { data in
        //                let encodingdfgdf = encoding
        //                let data = data
        //                let chunk = String(data: data, encoding: String.Encoding.utf8)
        //                if chunk == nil {
        //                    throw ErrorMessage("Could not decode text")
        //                }
        //                str += chunk!
        //            })
        //                .then { () -> String in
        //                str
        //            }
        //        }
    }

    public func getContentLength() throws -> Int64 {
        if let lengthHeader = self.headers.get("Content-Length") {
            if let lengthIsANumber = Int64(lengthHeader) {
                return lengthIsANumber
            } else {
                throw ErrorMessage("Content-Length header must be a number")
            }
        } else {
            throw ErrorMessage("Responses must send a Content-Length header")
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

    public func text(_ callback: @escaping (Error?, String?) -> Void) {
        self.data { err, data in

            if err != nil {
                callback(err, nil)
                return
            }

            do {

                var charset = String.Encoding.utf8

                if let contentTypeHeader = self.headers.get("Content-Type") {
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
                }

                let asString = String(data: data!, encoding: charset)
                callback(nil, asString)

            } catch {
                callback(error, nil)
            }
        }
    }

    func json() -> JSValue {
        let promise = JSPromise(context: jsContext!)

        json { err, json in
            if err != nil {
                promise.reject(err!)
            } else {
                promise.fulfill(json)
            }
        }

        return promise.jsValue
    }

    func text() -> JSValue {

        let promise = JSPromise(context: jsContext!)

        text { err, text in
            if err != nil {
                promise.reject(err!)
            } else {
                promise.fulfill(text)
            }
        }

        return promise.jsValue
    }

    internal func arrayBuffer() -> JSValue {

        let promise = JSPromise(context: jsContext!)

        data { err, data in

            if err != nil {
                promise.reject(err!)
                return
            }

            var d = data!

            let arr = d.withUnsafeMutableBytes { pointer -> JSObjectRef in
                return JSObjectMakeArrayBufferWithBytesNoCopy(self.jsContext!.jsGlobalContextRef, pointer, data!.count, { _, _ in
                    // TODO: WTF to do with this
                    NSLog("Deallocate!")
                }, nil, nil)
            }
            let asJSVal = JSValue(jsValueRef: arr, in: self.jsContext!)
            promise.fulfill(asJSVal)
        }

        return promise.jsValue
    }

    public func json(_ callback: @escaping (Error?, Any?) -> Void) {

        self.data { err, data in

            if err != nil {
                callback(err, nil)
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                callback(nil, json)
            } catch {
                callback(error, nil)
            }
        }
    }

    public init(headers: FetchHeaders, status: Int, url: URL, redirected: Bool, fetchOperation: FetchOperation?, stream: ReadableStream? = nil) {
        self.fetchOperation = fetchOperation
        self.responseCallback = nil
        self.headers = headers
        self.status = status
        self.url = url
        self.redirected = redirected
        super.init()

        if let str = stream {
            // We can override the underlying stream if we want - this is used
            // in OpaqueResponse to ensure we don't actually provide the response
            // body
            self.dataStream = str
            self.streamController = str.controller
        } else {
            // Otherwise we create another new stream and hook up the fetch
            // operation.

            self.dataStream = ReadableStream(start: { controller in
                self.streamController = controller
            })

            if let op = fetchOperation {
                op.add(delegate: self)
            }
        }
    }

    init(response: HTTPURLResponse, operation: FetchOperation, callback: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.fetchOperation = operation
        self.responseCallback = callback
        self.status = response.statusCode
        self.url = response.url!
        self.redirected = operation.redirected

        // Convert to our custom FetchHeaders class
        let headers = FetchHeaders()
        response.allHeaderFields.keys.forEach { key in

            let keyString = key as! String
            let value = response.allHeaderFields[key] as! String

            if keyString.lowercased() == "content-encoding" {
                // URLSession automatically decodes content (which we don't actually want it to do)
                // so the only way to continue to use this is to strip out the Content-Encoding
                // header, otherwise the browser will try to decode it again
                return
            } else if keyString.lowercased() == "content-length" {
                // Because of this same GZIP issue, the content length will be incorrect. It's actually
                // also normally incorrect, but because we're stripping out all encoding we should
                // update the content-length header to be accurate.
                headers.set("Content-Length", String(operation.task!.countOfBytesExpectedToReceive))
                return
            }

            headers.set(keyString, value)
        }

        self.headers = headers

        super.init()

        dataStream = ReadableStream(start: { controller in
            self.streamController = controller
        })

        // since this is being created directly from native, we know we want
        // it to be a delegate
        operation.add(delegate: self)
    }

    deinit {
        if self.fetchOperation?.task!.state == .running {
            Log.warn?("Terminating currently pending fetch operation for: " + self.fetchOperation!.request.url.absoluteString)
            self.fetchOperation!.task!.cancel()
        }
    }
}
