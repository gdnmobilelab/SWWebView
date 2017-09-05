//
//  OpaqueResponse.swift
//  ServiceWorker
//
//  Created by alastair.coote on 20/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc class OpaqueResponse: FetchResponseProxy {

    override var responseType: ResponseType {
        return .Opaque
    }

    let emptyHeaders = FetchHeaders()
    let emptyStream: ReadableStream

    override var headers: FetchHeaders {
        return self.emptyHeaders
    }

    override func getReader() throws -> ReadableStream {
        return self.emptyStream
    }

    override func text() -> Promise<String> {
        return Promise(value: "")
    }

    override func text() -> JSValue? {

        let promise = JSPromise(context: JSContext.current())
        promise.fulfill("")
        return promise.jsValue
    }

    override func json() -> Promise<Any?> {
        return Promise(error: ErrorMessage("Could not decode JSON content in opaque response"))
    }

    override func json() -> JSValue? {

        let promise = JSPromise(context: JSContext.current())
        promise.fulfill(NSNull())
        return promise.jsValue
    }

    override init(from response: FetchResponse) throws {

        self.emptyStream = ReadableStream()

        try self.emptyStream.controller.close()

        try super.init(from: response)
    }
}
