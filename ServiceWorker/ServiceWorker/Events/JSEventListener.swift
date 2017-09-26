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
