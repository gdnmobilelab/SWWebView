import Foundation
import JavaScriptCore

@objc public protocol WorkerLocationExports: JSExport {
    var href: String { get }
    var `protocol`: String { get }

    var host: String { get }
    var hostname: String { get }
    var origin: String { get }
    var port: String { get }
    var pathname: String { get }
    var search: String { get }
    var searchParams: URLSearchParams { get }
}

/// Basically the same as URL as far as I can, except for the fact that it is
/// read-only. https://developer.mozilla.org/en-US/docs/Web/API/WorkerLocation
@objc(WorkerLocation) public class WorkerLocation: LocationBase, WorkerLocationExports {
}
