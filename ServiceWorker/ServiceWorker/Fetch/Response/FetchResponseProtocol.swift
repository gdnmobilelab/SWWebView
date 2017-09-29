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

    //    func getReader() throws -> ReadableStream
    func json() -> JSValue?
    func text() -> JSValue?
    func arrayBuffer() -> JSValue?

    @objc(clone)
    func cloneResponseExports() -> FetchResponseJSExports?
}

@objc public protocol ConstructableFetchResponseJSExports: FetchResponseJSExports, JSExport {
    init(body: JSValue, options: [String: Any]?)
}

@objc public protocol CacheableFetchResponse: FetchResponseJSExports {
    var internalResponse: FetchResponse { get }
}

public protocol FetchResponseProtocol: FetchResponseJSExports {
    func clone() throws -> FetchResponseProtocol
    var internalResponse: FetchResponse { get }
    var responseType: ResponseType { get }
    func text() -> Promise<String>
    func data() -> Promise<Data>
    func json() -> Promise<Any?>
    var url: URL? { get }
}
