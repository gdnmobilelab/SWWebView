import Foundation
import JavaScriptCore

@objc public protocol Event: JSExport {
    var type: String { get }
}
