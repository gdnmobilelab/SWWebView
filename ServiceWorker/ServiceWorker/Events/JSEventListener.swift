import Foundation
import JavaScriptCore

/// A wrapper around a JavaScript function, stored as a JSValue, to be called when
/// an event is dispatched. Also contains a reference to the correct thread to
/// run the function on.
class JSEventListener: EventListener {
    let eventName: String
    let funcToRun: JSValue
    let targetThread: Thread

    init(name: String, funcToRun: JSValue, thread: Thread) {
        self.eventName = name
        self.funcToRun = funcToRun
        self.targetThread = thread
    }

    func dispatch(_ event: Event) {
        self.funcToRun.perform(#selector(JSValue.call(withArguments:)), on: self.targetThread, with: [event], waitUntilDone: true)
    }
}
