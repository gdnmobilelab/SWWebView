import Foundation
import JavaScriptCore

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
        self.funcToRun.perform(#selector(JSValue.call(withArguments:)), on: self.targetThread, with: [event], waitUntilDone: false)
    }
}
