//
//  ExtendableEvent.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit

@objc protocol ExtendableEventExports: JSExport {
    func waitUntil(_: JSValue) -> Void
}

@objc public class ExtendableEvent: Event, ExtendableEventExports {

    public enum ExtendableEventState {
        case Valid
        case Invalid
        case Resolved
    }

    
    var state: ExtendableEventState = .Valid

    fileprivate var pendingPromises: [JSManagedValue] = []

    func waitUntil(_ val: JSValue) {
        
        if self.state == .Invalid {
            val.context.exception = JSValue(newErrorFromMessage: "Invalid state for waitUntil()", in: val.context)
            return
        }
        let managed = JSManagedValue(value: val, andOwner: self)!
        val.context.virtualMachine.addManagedReference(managed, withOwner: self)

        self.pendingPromises.append(managed)
    }

    fileprivate func clearManagedReferences() {
        self.pendingPromises.forEach { managed in
            managed.value.context.virtualMachine.removeManagedReference(managed, withOwner: self)
        }
        self.pendingPromises.removeAll()
    }

    deinit {
        self.clearManagedReferences()
    }

    public func resolve(in worker: ServiceWorker) -> Promise<Void> {

        self.state = .Resolved

        return Promise<Void> { fulfill, reject in

            let success: @convention(block) () -> Void = {
                fulfill(())
            }

            let failure: @convention(block) (JSValue) -> Void = { val in

                let err = ErrorMessage(val.objectForKeyedSubscript("message").toString())
                reject(err)
            }

            worker.withJSContext { context in

                let jsFunc = context.evaluateScript("""
                    (function(promises, success, failure) {
                        return Promise.all(promises).then(success).catch(failure)
                    })
                """)!

                jsFunc.call(withArguments: [self.pendingPromises, unsafeBitCast(success, to: AnyObject.self), unsafeBitCast(failure, to: AnyObject.self)])

                if context.exception != nil {
                    throw ErrorMessage(context.exception.toString())
                }

            }.catch { error in
                reject(error)
            }.always {
                self.clearManagedReferences()
            }
        }
    }
}
