import Foundation

public protocol MessagePortTarget: class {
    var started: Bool { get }
    func start()
    func receiveMessage(_: ExtendableMessageEvent)
    func close()
}
