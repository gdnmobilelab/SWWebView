//
//  ServiceWorker.swift
//  SWWebView
//
//  Created by alastair.coote on 10/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

extension ServiceWorker : ToJSON {
    func toJSONSuitableObject() -> Any {
        return [
            "id": self.id,
            "installState": self.state.rawValue,
            "scriptURL": self.url.absoluteString
        ]
    }
}
