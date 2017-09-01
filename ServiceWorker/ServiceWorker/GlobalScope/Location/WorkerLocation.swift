//
//  WorkerLocation.swift
//  ServiceWorker
//
//  Created by alastair.coote on 25/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc public protocol WorkerLocationExports: JSExport {
    var href: String { get }

    @objc(protocol)
    var _protocol: String { get }

    var host: String { get }
    var hostname: String { get }
    var origin: String { get }
    var port: String { get }
    var pathname: String { get }
    var search: String { get }
}

@objc(WorkerLocation) public class WorkerLocation: LocationBase, WorkerLocationExports {

    /// We can't use 'hash' as a property in native code because it's used by Objective C (grr)
    /// so we have to resort to this total hack to get hash back.
    static func addToWorkerContext(context: JSContext) {

        context.globalObject.setValue(WorkerLocation.self, forProperty: "WorkerLocation")
        let jsInstance = context.globalObject.objectForKeyedSubscript("WorkerLocation")!

        // Also add it to the self object
        context.globalObject.objectForKeyedSubscript("self")
            .setValue(jsInstance, forProperty: "WorkerLocation")

        // Now graft in our awful hacks to get and set hash
        context.objectForKeyedSubscript("Object")
            .objectForKeyedSubscript("defineProperty")
            .call(withArguments: [jsInstance.objectForKeyedSubscript("prototype"), "hash", [
                "get": unsafeBitCast(self.hashGetter, to: AnyObject.self)
            ]])
    }
}
