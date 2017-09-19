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
    var portOne: SWMessagePort { get }
    var portTwo: SWMessagePort { get }
}

@objc public class MessageChannel: NSObject, MessageChannelExports {
    public let portOne: SWMessagePort
    public let portTwo: SWMessagePort

    override init() {
        self.portOne = SWMessagePort()
        self.portTwo = SWMessagePort()
        super.init()
        self.portOne.targetPort = portTwo
        self.portTwo.targetPort = self.portOne
    }
}
