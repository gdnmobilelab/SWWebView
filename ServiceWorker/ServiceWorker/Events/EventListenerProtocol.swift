import Foundation

protocol EventListener {
    func dispatch(_: Event)
    var eventName: String { get }
}
