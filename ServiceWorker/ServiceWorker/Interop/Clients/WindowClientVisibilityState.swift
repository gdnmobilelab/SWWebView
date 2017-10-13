import Foundation

/// As outlined here: https://developer.mozilla.org/en-US/docs/Web/API/WindowClient/visibilityState
@objc public enum WindowClientVisibilityState: Int {
    case Hidden
    case Visible
    case Prerender
    case Unloaded
}

// Objective C doesn't like string enums, so instead we're using an extension.
public extension WindowClientVisibilityState {
    var stringValue: String {
        switch self {
        case .Hidden:
            return "hidden"
        case .Prerender:
            return "prerender"
        case .Unloaded:
            return "unloaded"
        case .Visible:
            return "visible"
        }
    }
}
