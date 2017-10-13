import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol WindowClientExports: JSExport {
    func focus() -> JSValue?
    func navigate(_ url: String) -> JSValue?
    var focused: Bool { get }
    var visibilityState: String { get }
}

/// A more specific version of Client, WindowClient: https://developer.mozilla.org/en-US/docs/Web/API/WindowClient
/// also provides information on visibility and focus state (that don't apply to workers etc)
@objc class WindowClient: Client, WindowClientExports {

    let wrapAroundWindow: WindowClientProtocol

    init(wrapping: WindowClientProtocol) {
        self.wrapAroundWindow = wrapping
        super.init(client: wrapping)
    }

    func focus() -> JSValue? {

        return Promise<Client> { fulfill, reject in

            wrapAroundWindow.focus { err, windowClient in
                if let error = err {
                    reject(error)
                } else if let client = windowClient {
                    fulfill(Client.getOrCreate(from: client))
                }
            }
        }
        .toJSPromiseInCurrentContext()
    }

    func navigate(_ url: String) -> JSValue? {

        return Promise<WindowClientProtocol> { fulfill, reject in
            guard let parsedURL = URL(string: url, relativeTo: nil) else {
                return reject(ErrorMessage("Could not parse URL returned by native implementation"))
            }

            self.wrapAroundWindow.navigate(to: parsedURL) { err, windowClient in
                if let error = err {
                    reject(error)
                } else if let window = windowClient {
                    fulfill(window)
                }
            }
        }.toJSPromiseInCurrentContext()
    }

    var focused: Bool {
        return self.wrapAroundWindow.focused
    }

    var visibilityState: String {
        return self.wrapAroundWindow.visibilityState.stringValue
    }
}
