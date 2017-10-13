import Foundation

/// Outlined here: https://developer.mozilla.org/en-US/docs/Web/API/Clients/matchAll, though
/// not sure we'll ever implement Worker or SharedWorker (not sure how we'd know about them)
@objc public enum ClientType: Int {
    case Window
    case Worker
    case SharedWorker
}

// Can't use string enums because Objective C doesn't like them
extension ClientType {

    var stringValue: String {
        switch self {
        case .SharedWorker:
            return "sharedworker"
        case .Window:
            return "window"
        case .Worker:
            return "worker"
        }
    }
}
