//
//  GlobalFetch.swift
//  ServiceWorker
//
//  Created by alastair.coote on 06/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

@objc public class GlobalFetch: NSObject, URLSessionDelegate, URLSessionDataDelegate {

    // We store all our pending responses here so that we can send the
    // appropriate delegate methods on
    fileprivate var pendingResponses = Set<FetchResponse>()

    static let `default` = GlobalFetch()

    fileprivate let session: URLSession

    override init() {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        super.init()
    }

    public func fetch(_ url: URL) -> Promise<FetchResponse> {
        let request = FetchRequest(url: url)
        return self.fetch(request)
    }

    public func fetch(_ request: FetchRequest) -> Promise<FetchResponse> {

        let nsRequest = request.toURLRequest()
        let task = self.session.dataTask(with: nsRequest)
        let response = FetchResponse(from: task)

        task.resume()
    }
}
