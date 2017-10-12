import Foundation
import JavaScriptCore
import PromiseKit

/// These are the FetchProtocol components that we expose to our JS environment
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

    init?(body: JSValue, options: [String: Any]?)
}

/// Then, in addition to the above, these are the elements we make available natively.
/// I think FetchResponseProxy is now the only class that implements these, so in theory
/// we could flatten this out.
public protocol FetchResponseProtocol: FetchResponseJSExports {
    func clone() throws -> FetchResponseProtocol
    var internalResponse: FetchResponse { get }
    var responseType: ResponseType { get }
    func text() -> Promise<String>
    func data() -> Promise<Data>
    func json() -> Promise<Any?>
    var streamPipe: StreamPipe? { get }
    var url: URL? { get }
}

/// Just to add a little complication to the mix, this is a special case for caching. Obj-C
/// can't represent the Promises in FetchResponseProtocol, so we have a special-case, Obj-C
/// compatible protocol that lets us get to the inner fetch response.
@objc public protocol CacheableFetchResponse: FetchResponseJSExports {
    var internalResponse: FetchResponse { get }
}
