import Foundation

/// Normally a MessagePort communicates with another MessagePort (as facilitated
/// by Message Channel) but at times we need to do something different, like set up
/// a proxy to send messages into a SWWebView. This protocol allows us to do that.
public protocol MessagePortTarget: class {
    var started: Bool { get }
    func start()
    func receiveMessage(_: ExtendableMessageEvent)
    func close()
}
