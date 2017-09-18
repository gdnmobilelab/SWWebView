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
}
