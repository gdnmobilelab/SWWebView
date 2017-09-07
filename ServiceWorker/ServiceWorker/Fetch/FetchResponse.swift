//
//  FetchResponse.swift
//  ServiceWorker
//
//  Created by alastair.coote on 06/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

@objc class FetchResponse: NSObject {

    var task: URLSessionDataTask?

    fileprivate var headersReceivedPromise: Promise<Void>.PendingTuple

    internal var headersReceived: Promise<Void> {
        return self.headersReceivedPromise.0
    }

    init(from task: URLSessionDataTask) {
        self.task = task
        self.headersReceivedPromise = Promise<Void>.pending()
        super.init()
    }
}
