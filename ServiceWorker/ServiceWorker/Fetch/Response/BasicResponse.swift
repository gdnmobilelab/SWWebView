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

    fileprivate static func filterHeaders(_ headers: FetchHeaders) -> FetchHeaders {
        let filteredHeaders = FetchHeaders()

        filteredHeaders.values = headers.values.filter { header in
            return header.key.lowercased() != "set-cookie" && header.key.lowercased() != "set-cookie2"
        }

        return filteredHeaders
    }

    override init(from response: FetchResponse) throws {

        self.filteredHeaders = BasicResponse.filterHeaders(response.headers)

        try super.init(from: response)
    }
}
