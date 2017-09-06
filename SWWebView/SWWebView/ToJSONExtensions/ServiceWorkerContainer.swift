//
//  ServiceWorkerContainer.swift
//  SWWebView
//
//  Created by alastair.coote on 18/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer

extension ServiceWorkerContainer: ToJSON {
    func toJSONSuitableObject() -> Any {
        return [
            "readyRegistration": (self.readyRegistration as? ServiceWorkerRegistration)?.toJSONSuitableObject(),
            "controller": self.controller?.toJSONSuitableObject()
        ]
    }
}
