//
//  FetchResponseProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 21/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc public protocol FetchResponseJSExports: JSExport {
    var headers: FetchHeaders { get }
    var statusText: String { get }
    var ok: Bool { get }
    var redirected: Bool { get }
    var bodyUsed: Bool { get }
    var status: Int { get }

    @objc(type)
    var responseTypeString: String { get }

    @objc(url)
    var urlString: String { get }

    func getReader() throws -> ReadableStream
    func json() -> JSValue
    func text() -> JSValue
    func arrayBuffer() -> JSValue

    @objc(clone)
    func cloneResponseExports() -> FetchResponseJSExports?
}

public protocol FetchResponseProtocol: FetchResponseJSExports {
    func clone() throws -> FetchResponseProtocol
    var internalResponse: FetchResponse { get }
    var responseType: ResponseType { get }
    func json(_: @escaping (Error?, Any?) -> Void)
    func text(_: @escaping (Error?, String?) -> Void)
    func text() -> Promise<String>
    func data() -> Promise<Data>
    var url: URL { get }
}
