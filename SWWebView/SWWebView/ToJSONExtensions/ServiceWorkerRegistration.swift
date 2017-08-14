//
//  ServiceWorkerRegistration.swift
//  SWWebView
//
//  Created by alastair.coote on 10/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer

extension ServiceWorkerRegistration : ToJSON {
    func toJSONSuitableObject() -> Any {
        
       return [
            "scope": self.scope.absoluteString,
            "active": self.active?.toJSONSuitableObject(),
            "waiting": self.waiting?.toJSONSuitableObject(),
            "installing": self.installing?.toJSONSuitableObject(),
            "redundant": self.redundant?.toJSONSuitableObject()
        ]
    }
}
