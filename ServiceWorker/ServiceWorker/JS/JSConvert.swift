import Foundation
import JavaScriptCore

// protocol OptionalType {}
//
// extension Optional: OptionalType {
//    static func create() -> Optional {
//        return nil
//    }
// }

class JSConvert {

    enum VoidReturn {}

    //
    //    static func from(jsValue: JSValue) throws -> Any? {
    //        if T.self == JSContextPromise.self {
    //
    //            guard let thread = ServiceWorkerExecutionEnvironment.contexts.object(forKey: jsValue.context)?.thread else {
    //                throw ErrorMessage("Could not get execution environment for this value")
    //            }
    //
    //            guard let asPromise = JSContextPromise(jsValue: jsValue, thread: thread) as? T else {
    //                throw ErrorMessage("Could not convert to generic - this should never happen")
    //            }
    //
    //            return asPromise
    //
    //        } else {
    //
    //            return jsValue.toObject()
    //        }
    //    }

    static func from<T>(any: Any?) throws -> T {
        if T.self == Void.self, let voidResult = () as? T {
            return voidResult
        }

        guard let transformed = any as? T else {
            throw ErrorMessage("Could not convert \(any ?? "nil") to type \(T.self)")
        }

        return transformed
    }
}
