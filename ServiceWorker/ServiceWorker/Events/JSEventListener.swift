//
//  JSEventListener.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

class JSEventListener: EventListener {
    let eventName: String
    let funcToRun: JSValue

    init(name: String, funcToRun: JSValue) {
        self.eventName = name
        self.funcToRun = funcToRun
    }

    func dispatch(_ event: Event) {
        self.funcToRun.call(withArguments: [event])
    }
}
