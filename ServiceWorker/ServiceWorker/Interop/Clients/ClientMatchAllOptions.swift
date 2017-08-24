//
//  ClientMatchAllOptions.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public class ClientMatchAllOptions : NSObject {
    let includeUncontrolled:Bool
    let type:String
    
    init(includeUncontrolled:Bool, type: String) {
        self.includeUncontrolled = includeUncontrolled
        self.type = type
    }
}
