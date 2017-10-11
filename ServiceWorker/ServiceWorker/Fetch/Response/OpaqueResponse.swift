import Foundation
import JavaScriptCore
import PromiseKit

@objc class OpaqueResponse: FetchResponseProxy {

    override var responseType: ResponseType {
        return .Opaque
    }

    let emptyHeaders = FetchHeaders()

    override func data() -> Promise<Data> {
        return Promise(value: Data(count: 0))
    }

    override func text() -> Promise<String> {
        return Promise(value: "")
    }

    override func json() -> Promise<Any?> {
        return Promise(value: nil)
    }

    override var headers: FetchHeaders {
        return self.emptyHeaders
    }

    override init(from response: FetchResponse) throws {
        try super.init(from: response)
    }
}
