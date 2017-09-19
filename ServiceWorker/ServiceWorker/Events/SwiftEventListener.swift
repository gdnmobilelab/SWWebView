//
//  SwiftEventListener.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

class SwiftEventListener<T>: NSObject, EventListener {
    let eventName: String
    let callback: (T) -> Void

    init(name: String, _ callback: @escaping (T) -> Void) {
        self.eventName = name
        self.callback = callback
        super.init()
    }

    func dispatch(_ event: Event) {
        if let specificEvent = event as? T {
            self.callback(specificEvent)
        } else {
            Log.warn?("Dispatched event \(event), but this listener is for type \(T.self)")
        }
    }
}
