import Foundation
import JavaScriptCore

@objc class BasicResponse: FetchResponseProxy {

    fileprivate let filteredHeaders: FetchHeaders

    override var responseType: ResponseType {
        return .Basic
    }

    override var headers: FetchHeaders {
        return self.filteredHeaders
    }

    override init(from response: FetchResponse) throws {
        let filteredHeaders = FetchHeaders()

        filteredHeaders.values = response.headers.values.filter { header in
            return header.key.lowercased() != "set-cookie" && header.key.lowercased() != "set-cookie2"
        }

        self.filteredHeaders = filteredHeaders

        try super.init(from: response)
    }
}
