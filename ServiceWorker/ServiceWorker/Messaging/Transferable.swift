import Foundation

/// On the web this is for MessagePorts, ImageBitmaps and ArrayBuffers
/// but for now we're just focusing on MessagePorts. Getting things like
/// ArrayBuffers into SWWebView will be a pain, but not impossible. SharedArrayBuffers
/// probably are impossible, though.
@objc public protocol Transferable {
}
