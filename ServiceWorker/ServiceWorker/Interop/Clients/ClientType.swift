import Foundation

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
