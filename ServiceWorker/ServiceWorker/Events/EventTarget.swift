//
//  EventTarget.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

private struct EventListener {
    let eventName: String
    let funcToRun: JSValue
}

@objc protocol EventTargetExports: JSExport {

    func addEventListener(_ name: String, _ funcToRun: JSValue)
    func removeEventListener(_ name: String, _ funcToRun: JSValue)
    func dispatchEvent(_ event: Event)
}

/// Replicating the base EventTarget class used throughout the browser:
/// https://developer.mozilla.org/en-US/docs/Web/API/EventTarget
@objc class EventTarget: NSObject, EventTargetExports {

    fileprivate var listeners: [EventListener] = []

    override init() {
        super.init()
    }

    func addEventListener(_ name: String, _ funcToRun: JSValue) {

        let existing = listeners.first(where: { $0.eventName == name && $0.funcToRun == funcToRun })

        if existing != nil {
            return
        }

        self.listeners.append(EventListener(eventName: name, funcToRun: funcToRun))
    }

    func removeEventListener(_ name: String, _ funcToRun: JSValue) {
        guard let existing = listeners.index(where: { $0.eventName == name && $0.funcToRun == funcToRun }) else {
            Log.debug?("Tried to remove event listener when it was not attached")
            return
        }

        self.listeners.remove(at: existing)
    }

    func dispatchEvent(_ event: Event) {

        self.listeners
            .filter { $0.eventName == event.type }
            .forEach { $0.funcToRun.call(withArguments: [event]) }
    }

    func clearAllListeners() {
        self.listeners.removeAll()
    }

    static func applyJavaScriptListeners(_ from: EventTarget, to context: JSContext) {

        let addConvention: @convention(block) (String, JSValue) -> Void = { name, funcToRun in
            from.addEventListener(name, funcToRun)
        }
        GlobalVariableProvider.add(variable: addConvention, to: context, withName: "addEventListener")

        let removeConvention: @convention(block) (String, JSValue) -> Void = { name, funcToRun in
            from.removeEventListener(name, funcToRun)
        }

        GlobalVariableProvider.add(variable: removeConvention, to: context, withName: "removeEventListener")

        let dispatchConvention: @convention(block) (Event) -> Void = { event in
            from.dispatchEvent(event)
        }

        GlobalVariableProvider.add(variable: dispatchConvention, to: context, withName: "dispatchEvent")
    }
}
