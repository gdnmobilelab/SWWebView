//
//  JSPromise.swift
//  ServiceWorker
//
//  Created by alastair.coote on 23/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

class JSPromise {

    unowned let context: JSContext
    let virtualMachine:JSVirtualMachine
    fileprivate var fulfill: JSManagedValue?
    fileprivate var reject: JSManagedValue?
    fileprivate var promiseJSValue: JSManagedValue?

    public init(context: JSContext) {
        self.context = context
        self.virtualMachine = context.virtualMachine
        let capture: @convention(block) (JSValue, JSValue) -> Void = { (fulfillVal: JSValue, rejectVal: JSValue) in

            let fulfillManaged = JSManagedValue(value: fulfillVal)
            let rejectManaged = JSManagedValue(value: rejectVal)

            self.virtualMachine.addManagedReference(fulfillManaged, withOwner: self)
            self.virtualMachine.addManagedReference(rejectManaged, withOwner: self)

            self.fulfill = fulfillManaged
            self.reject = rejectManaged
        }

        let val = self.context.objectForKeyedSubscript("Promise")!.construct(withArguments: [unsafeBitCast(capture, to: AnyObject.self)])
        promiseJSValue = JSManagedValue(value: val)
        self.virtualMachine.addManagedReference(self.jsValue, withOwner: self)
    }

    public var jsValue: JSValue {
        return self.promiseJSValue!.value
    }

    deinit {
        self.virtualMachine.removeManagedReference(self.fulfill, withOwner: self)
        self.virtualMachine.removeManagedReference(self.reject, withOwner: self)
        self.virtualMachine.removeManagedReference(self.jsValue, withOwner: self)
    }

    public func fulfill(_ value: Any?) {
        if value == nil {
            self.fulfill!.value.call(withArguments: [NSNull()])
        } else {
            self.fulfill!.value.call(withArguments: [value!])
        }
    }

    public func reject(_ error: Error) {

        var str = String(describing: error)
        if let errMsg = error as? ErrorMessage {
            str = errMsg.message
        }

        let err = JSValue(newErrorFromMessage: str, in: context)

        reject!.value.call(withArguments: [err!])
    }

    public static func fromJSValue(_ promise: JSValue) -> Promise<JSManagedValue?> {

        return Promise { fulfill, reject in

            let reject: @convention(block) (JSValue) -> Void = { err in
                reject(ErrorMessage(err.objectForKeyedSubscript("message").toString()))
            }
            let fulfill: @convention(block) (JSValue?) -> Void = { result in
                fulfill(JSManagedValue(value: result))
            }

            let bindFunc = promise.context.evaluateScript("(function(promise,thenFunc,catchFunc) { return promise.then(thenFunc).catch(catchFunc)})")!

            bindFunc.call(withArguments: [promise, unsafeBitCast(fulfill, to: AnyObject.self), unsafeBitCast(reject, to: AnyObject.self)])
        }
    }

    public static func resolve(_ promise: JSValue, _ cb: @escaping (Error?, JSValue?) -> Void) {

        let reject: @convention(block) (JSValue) -> Void = { err in
            cb(ErrorMessage(err.objectForKeyedSubscript("message").toString()), nil)
        }
        let fulfill: @convention(block) (JSValue?) -> Void = { result in
            cb(nil, result)
        }

        let bindFunc = promise.context.evaluateScript("(function(promise,thenFunc,catchFunc) { return promise.then(thenFunc).catch(catchFunc)})")!

        bindFunc.call(withArguments: [promise, unsafeBitCast(fulfill, to: AnyObject.self), unsafeBitCast(reject, to: AnyObject.self)])
    }
}
