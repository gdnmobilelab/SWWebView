//
//  TestWeb.swift
//  ServiceWorkerContainerTests
//
//  Created by alastair.coote on 22/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import GCDWebServers

class TestWeb {

    static var server: GCDWebServer?

    static var serverURL: URL {
        var url = URLComponents(string: "http://localhost")!
        url.port = Int(server!.port)
        return url.url!
    }

    static func createServer() {
        URLCache.shared.removeAllCachedResponses()
        self.server = GCDWebServer()
        self.server!.start()
    }

    static func destroyServer() {
        self.server!.stop()
        self.server = nil
    }
}
