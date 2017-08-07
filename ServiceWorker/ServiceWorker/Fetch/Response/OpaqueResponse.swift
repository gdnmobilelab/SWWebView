//
//  OpaqueResponse.swift
//  ServiceWorker
//
//  Created by alastair.coote on 20/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

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

    override func text() -> JSValue {

        let promise = JSPromise(context: _internal.jsContext!)
        promise.fulfill("")
        return promise.jsValue
    }

    override func text(_ cb: @escaping (Error?, String?) -> Void) {
        cb(nil, "")
    }

    override func json() -> JSValue {

        let promise = JSPromise(context: _internal.jsContext!)
        promise.fulfill(NSNull())
        return promise.jsValue
    }

    override func json(_ cb: @escaping (Error?, Any?) -> Void) {
        cb(nil, NSNull())
    }

    override init(from response: FetchResponse) {

        self.emptyStream = ReadableStream(start: { controller in
            controller.close()
        })

        super.init(from: response)
    }
}
