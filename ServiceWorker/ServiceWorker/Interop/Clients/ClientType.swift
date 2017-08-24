//
//  ClientType.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public enum ClientType : Int {
    case Window
    case Worker
    case SharedWorker
}

// Can't use string enums because Objective C doesn't like them
extension ClientType {
    
    var stringValue:String {
        get {
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
}
