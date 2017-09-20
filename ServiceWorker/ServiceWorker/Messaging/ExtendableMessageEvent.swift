//
//  MessageEvent.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol MessageEventExports: EventExports, JSExport {
    var data: Any { get }
    var ports: [SWMessagePort] { get }
}

@objc public class ExtendableMessageEvent: ExtendableEvent, MessageEventExports {
    public let data: Any
    public let ports: [SWMessagePort]

    public init(data: Any, ports: [SWMessagePort] = []) {
        self.data = data
        self.ports = ports
        super.init(type: "message")
    }

    public required init(type _: String) {
        fatalError("MessageEvent must be initialized with data")
    }
}
