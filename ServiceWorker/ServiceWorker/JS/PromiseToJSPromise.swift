//
//  PromiseToJSPromise.swift
//  ServiceWorker
//
//  Created by alastair.coote on 26/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import JavaScriptCore

extension Promise {
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
