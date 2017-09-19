//
//  MessageEvent.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol MessageEventExports: EventExports, JSExport {
    var data: Any { get }
}

@objc class MessageEvent: Event, MessageEventExports {
    let data: Any

    init(data: Any) {
        self.data = data
        super.init(type: "message")
    }

    public required init(type _: String) {
        fatalError("MessageEvent must be initialized with data")
    }
}
