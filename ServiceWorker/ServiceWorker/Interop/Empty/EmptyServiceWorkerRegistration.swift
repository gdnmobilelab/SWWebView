//
//  DummyServiceWorkerRegistration.swift
//  ServiceWorker
//
//  Created by alastair.coote on 16/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public class EmptyServiceWorkerRegistration: NSObject, ServiceWorkerRegistrationProtocol {

    public func showNotification(_ title: JSValue) -> JSValue {
        let promise = JSPromise(context: title.context)
        promise.reject(ErrorMessage("ServiceWorkerRegistration implementation not provided"))
        return promise.jsValue
    }
    
    public var id: String {
        get {
            return "empty"
        }
    }
}
