import Foundation
import JavaScriptCore

/// The representation of a webview that a service worker sees.
@objc public protocol ClientProtocol {
    func postMessage(message: Any?, transferable: [Any]?)
    var id: String { get }
    var type: ClientType { get }
    var url: URL { get }
}
