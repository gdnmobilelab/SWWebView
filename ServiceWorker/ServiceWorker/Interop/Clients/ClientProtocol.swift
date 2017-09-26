import Foundation
import JavaScriptCore

@objc public protocol ClientProtocol {
    func postMessage(message: Any?, transferable: [Any]?)
    var id: String { get }
    var type: ClientType { get }
    var url: URL { get }
}
