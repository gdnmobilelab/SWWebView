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
