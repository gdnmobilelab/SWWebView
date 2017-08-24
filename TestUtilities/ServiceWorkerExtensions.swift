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
    static func createTestWorker(id: String = "TEST", state: ServiceWorkerInstallState = .activated, content: String = "") -> ServiceWorker {
        return ServiceWorker(id: id, url: URL(string: "http://www.example.com/\(id).js")!, state: state.rawValue, content: content)
    }
    
    static func createTestWorker(implementations:WorkerImplementations) -> ServiceWorker {
        return ServiceWorker(id: "TEST", url: URL(string: "http://www.example.com/TEST.js")!, implementations: implementations, state: "activated", content: "")
    }
    
    static func createTestWorker(content: String) -> ServiceWorker {
        return ServiceWorker.createTestWorker(id: "TEST", state: .activated, content: content)
    }
}
