//
//  ErrorMessage.swift
//  ServiceWorker
//
//  Created by alastair.coote on 01/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

public class ErrorMessage: Error, CustomStringConvertible {
    
    public let message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var description: String {
        return self.message
    }
}

