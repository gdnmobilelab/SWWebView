import Foundation
import PromiseKit
import JavaScriptCore

public extension Promise {

    public func toJSPromiseInCurrentContext() -> JSValue? {

        let jsp = JSContextPromise.makeInCurrentContext()

        then { response -> Void in
            NSLog("Fulfilling JSPromise with \(response)")

            jsp.fulfill(response)
        }
        .catch { error in
            jsp.reject(error)
        }

        return jsp.jsValue
    }
}
