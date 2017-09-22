//
//  MessageChannel.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol MessageChannelExports: JSExport {
    var port1: SWMessagePort { get }
    var port2: SWMessagePort { get }
    init()
}

@objc public class MessageChannel: NSObject, MessageChannelExports {
    public let port1: SWMessagePort
    public let port2: SWMessagePort

    public required override init() {
        self.port1 = SWMessagePort()
        self.port2 = SWMessagePort()
        super.init()
        self.port1.targetPort = port2
        self.port2.targetPort = self.port1
    }
}
