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
