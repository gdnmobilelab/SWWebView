import Foundation
import JavaScriptCore

@objc protocol WindowClientExports: JSExport {
    func focus() -> JSValue?
    func navigate(_ url: String) -> JSValue?
    var focused: Bool { get }
    var visibilityState: String { get }
}

@objc class WindowClient: Client, WindowClientExports {

    let wrapAroundWindow: WindowClientProtocol

    init(wrapping: WindowClientProtocol, in context: JSContext) {
        self.wrapAroundWindow = wrapping
        super.init(wrapping: wrapping, in: context)
    }

    func focus() -> JSValue? {
        let jsp = JSPromise(context: context)

        wrapAroundWindow.focus(jsp.processCallback(transformer: { windowClientProtocol in
            Client.getOrCreate(from: windowClientProtocol, in: self.context)
        }))

        return jsp.jsValue
    }

    func navigate(_ url: String) -> JSValue? {

        let jsp = JSPromise(context: context)

        guard let parsedURL = URL(string: url, relativeTo: nil) else {
            jsp.reject(ErrorMessage("Could not parse URL returned by native implementation"))
            return jsp.jsValue
        }

        self.wrapAroundWindow.navigate(to: parsedURL, jsp.processCallback(transformer: { windowClient in
            Client.getOrCreate(from: windowClient, in: self.context)
        }))

        return jsp.jsValue
    }

    var focused: Bool {
        return self.wrapAroundWindow.focused
    }

    var visibilityState: String {
        return self.wrapAroundWindow.visibilityState.stringValue
    }
}
