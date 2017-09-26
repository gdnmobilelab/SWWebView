import Foundation
import JavaScriptCore

@objc protocol EventTargetExports: JSExport {

    func addEventListener(_ name: String, _ funcToRun: JSValue)
    func removeEventListener(_ name: String, _ funcToRun: JSValue)
    func dispatchEvent(_ event: Event)
}

/// Replicating the base EventTarget class used throughout the browser:
/// https://developer.mozilla.org/en-US/docs/Web/API/EventTarget
@objc public class EventTarget: NSObject, EventTargetExports {

    fileprivate var listeners: [EventListener] = []

    func addEventListener(_ name: String, _ funcToRun: JSValue) {

        let existing = listeners.first(where: { listener in

            guard let jsListener = listener as? JSEventListener else {
                return false
            }

            return jsListener.eventName == name && jsListener.funcToRun == funcToRun

        })

        if existing != nil {
            return
        }

        self.listeners.append(JSEventListener(name: name, funcToRun: funcToRun))
    }

    func addEventListener<T>(_ name: String, _ callback: @escaping (T) -> Void) -> SwiftEventListener<T> {
        // You can't compare closures, so we just add it.
        let listener = SwiftEventListener(name: name, callback)
        self.listeners.append(listener)
        return listener
    }

    func removeEventListener<T>(_ listener: SwiftEventListener<T>) {
        guard let idx = self.listeners.index(where: { existingListener in

            if let swiftListener = existingListener as? SwiftEventListener<T> {
                return swiftListener == listener
            }
            return false

        }) else {
            Log.error?("Tried to remove a listener that isn't attached")
            return
        }
        self.listeners.remove(at: idx)
    }

    func removeEventListener(_ name: String, _ funcToRun: JSValue) {
        guard let existing = listeners.index(where: { listener in

            guard let jsListener = listener as? JSEventListener else {
                return false
            }

            return jsListener.eventName == name && jsListener.funcToRun == funcToRun

        }) else {
            Log.error?("Tried to remove an event on \(name) but it doesn't exist")
            return
        }

        self.listeners.remove(at: existing)
    }

    func dispatchEvent(_ event: Event) {

        self.listeners
            .filter { $0.eventName == event.type }
            .forEach { $0.dispatch(event) }
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
