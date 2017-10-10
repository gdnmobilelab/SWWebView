import Foundation
import PromiseKit
import JavaScriptCore

extension ServiceWorkerExecutionEnvironment {

    class PromiseWrappedCall: NSObject {
        internal let fulfill: (Any?) -> Void
        internal let reject: (Error) -> Void
        internal let promise: Promise<Any?>

        override init() {
            (self.promise, self.fulfill, self.reject) = Promise<Any?>.pending()
        }

        func resolve() -> Promise<Any?> {
            return self.promise
        }

        func resolveVoid() -> Promise<Void> {
            return self.promise.then { _ in () }
        }
    }

    @objc enum EvaluateReturnType: Int {
        case void
        case object
        case promise
    }

    @objc internal class EvaluateScriptCall: PromiseWrappedCall {
        let script: String
        let url: URL?
        let returnType: EvaluateReturnType

        init(script: String, url: URL?, returnType: EvaluateReturnType = .object) {
            self.script = script
            self.url = url
            self.returnType = returnType
            super.init()
        }
    }

    @objc internal class WithJSContextCall: PromiseWrappedCall {
        typealias FuncType = (JSContext) throws -> Void
        let funcToRun: FuncType
        init(_ funcToRun: @escaping FuncType) {
            self.funcToRun = funcToRun
        }
    }

    @objc internal class DispatchEventCall: PromiseWrappedCall {
        let event: Event
        init(_ event: Event) {
            self.event = event
        }
    }
}
