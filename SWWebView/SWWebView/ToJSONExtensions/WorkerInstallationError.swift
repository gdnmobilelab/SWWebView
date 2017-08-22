//
//  WorkerInstallationError.swift
//  SWWebView
//
//  Created by alastair.coote on 22/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer

extension WorkerInstallationError : ToJSON {
    
    func toJSONSuitableObject() -> Any {
        return [
            "error": String(describing: self.error),
            "worker": self.worker.toJSONSuitableObject()
        ]
    }

}
