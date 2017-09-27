import Foundation
import PromiseKit
import JavaScriptCore

public extension Promise {
    func toJSPromise(in context: JSContext) -> JSValue? {

        let jsPromise = JSPromise(context: context)

        then { response in
            jsPromise.fulfill(response)
        }
        .catch { error in
            jsPromise.reject(error)
        }

        return jsPromise.jsValue
    }
}
