//
//  CORSResponse.swift
//  ServiceWorker
//
//  Created by alastair.coote on 20/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

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

    init(from response: FetchResponse, allowedHeaders: [String]?) {

        self.allowedHeaders = allowedHeaders
        let filteredHeaders = FetchHeaders()

        var allAllowedHeaders: [String] = []
        allAllowedHeaders.append(contentsOf: CORSHeaders)
        if allowedHeaders != nil {
            allAllowedHeaders.append(contentsOf: allowedHeaders!)
        }

        allAllowedHeaders.forEach { key in
            if let val = response.headers.get(key) {
                filteredHeaders.set(key, val)
            }
        }

        self.filteredHeaders = filteredHeaders

        super.init(from: response)
    }

    override func clone() throws -> FetchResponseProtocol {

        if bodyUsed {
            throw ErrorMessage("Cannot clone response: body already used")
        }

        let clone = cloneInternalResponse()

        return CORSResponse(from: clone, allowedHeaders: self.allowedHeaders)
    }
}
