//
//  WindowClientVisibilityState.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public enum WindowClientVisibilityState: Int {
    case Hidden
    case Visible
    case Prerender
    case Unloaded
}

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
