import JavaScriptCore

@objc protocol ConstructableEventExports: Event, JSExport {
    init(type: String)
}

@objc class ConstructableEvent: NSObject, ConstructableEventExports {
    let type: String

    required init(type: String) {
        self.type = type
    }
}
