import JavaScriptCore

@objc protocol ConstructableEventExports: Event, JSExport {
    init(type: String)
}

/// There are probably better ways of doing this, but this is a specific class allowing
/// client code to create events (i.e. new Event('test')) - originally this was a base
/// class every other Event extended, but that required they all implement the constructor
/// used here - which we don't want to do, in the case of things like FetchEvent.
@objc class ConstructableEvent: NSObject, ConstructableEventExports {
    let type: String

    required init(type: String) {
        self.type = type
    }
}
