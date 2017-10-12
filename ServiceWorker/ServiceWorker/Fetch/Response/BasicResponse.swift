import Foundation
import JavaScriptCore

/// As outlined here: https://developer.mozilla.org/en-US/docs/Web/API/Response/type, there are
/// different types of responses exposed to worker environments, depending on things like CORS
/// settings. In retrospect, we could have all of these in one class, switching on a type variable,
/// but 
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
