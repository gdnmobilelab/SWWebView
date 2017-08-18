//
//  ServiceWorkerExtensions.swift
//  hybrid
//
//  Created by alastair.coote on 01/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

extension ServiceWorker {
    static func createTestWorker(id: String = "TEST", state: ServiceWorkerInstallState = .activated) -> ServiceWorker {
        return ServiceWorker(id: id, url: URL(string: "http://www.example.com/\(id).js")!, registration: DummyServiceWorkerRegistration(), state: state.rawValue, content: "")
    }
}
