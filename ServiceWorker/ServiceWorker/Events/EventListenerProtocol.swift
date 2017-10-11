import Foundation

/// We have different types of event listener (JSEventLister and SwiftEventListener)
/// so we ensure that both adhere to this same protocol, allowing them to be used
/// interchangably.
protocol EventListener {
    func dispatch(_: Event)
    var eventName: String { get }
}
