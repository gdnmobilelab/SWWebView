import Foundation

/// Extension of ClientProtocol that specifically handles webviews
@objc public protocol WindowClientProtocol: ClientProtocol {
    func focus(_ cb: (Error?, WindowClientProtocol?) -> Void)
    func navigate(to: URL, _ cb: (Error?, WindowClientProtocol?) -> Void)

    var focused: Bool { get }
    var visibilityState: WindowClientVisibilityState { get }
}
