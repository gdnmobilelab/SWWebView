import Foundation
import JavaScriptCore

private var CORSHeaders = [
    "cache-control",
    "content-language",
    "content-type",
    "expires",
    "last-modified",
    "pragma"
]

@objc class CORSResponse: FetchResponseProxy {

    override var responseType: ResponseType {
        return .CORS
    }

    fileprivate let filteredHeaders: FetchHeaders

    override var headers: FetchHeaders {
        return self.filteredHeaders
    }

    fileprivate let allowedHeaders: [String]?

    init(from response: FetchResponse, allowedHeaders: [String]?) throws {

        self.allowedHeaders = allowedHeaders
        let filteredHeaders = FetchHeaders()

        var allAllowedHeaders: [String] = []
        allAllowedHeaders.append(contentsOf: CORSHeaders)
        if let allowed = allowedHeaders {
            allAllowedHeaders.append(contentsOf: allowed)
        }

        allAllowedHeaders.forEach { key in
            if let val = response.headers.get(key) {
                filteredHeaders.set(key, val)
            }
        }

        self.filteredHeaders = filteredHeaders

        try super.init(from: response)
    }

    override func clone() throws -> FetchResponseProtocol {

        if bodyUsed {
            throw ErrorMessage("Cannot clone response: body already used")
        }

        let clone = try self._internal.clone()

        return try CORSResponse(from: clone, allowedHeaders: self.allowedHeaders)
    }
}
