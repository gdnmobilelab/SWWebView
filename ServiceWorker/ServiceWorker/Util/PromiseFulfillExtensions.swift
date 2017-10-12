import Foundation
import PromiseKit

@objc class PromisePassthrough: NSObject {

    let fulfill: (Any?) -> Void
    let reject: (Error) -> Void

    init(fulfill: @escaping (Any?) -> Void, reject: @escaping (Error) -> Void) {
        self.fulfill = fulfill
        self.reject = reject
    }
}

extension Promise {
    static func makePassthrough() -> (promise: Promise<T>, passthrough: PromisePassthrough) {

        let (promise, fulfill, reject) = Promise<T>.pending()

        let fulfillCast = { (result: Any?) in

            if T.self == Void.self, let voidResult = () as? T {
                fulfill(voidResult)
                return
            }

            guard let cast = result as? T else {
                reject(ErrorMessage("Could not cast \(result ?? "nil") to desired type \(T.self)"))
                return
            }
            fulfill(cast)
        }

        let passthrough = PromisePassthrough(fulfill: fulfillCast, reject: reject)

        return (promise, passthrough)
    }

    func passthrough(_ target: PromisePassthrough) {
        self.then { result in
            target.fulfill(result)
        }
        .catch { error in
            target.reject(error)
        }
    }
}
