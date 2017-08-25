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
    
    static fileprivate func escapeID(_ id:String) -> String {
        return id.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
    }
    static func createTestWorker(id: String, state: ServiceWorkerInstallState = .activated, content: String = "") -> ServiceWorker {
        return ServiceWorker(id: id, url: URL(string: "http://www.example.com/\(escapeID(id)).js")!, state: state, content: content)
    }

    static func createTestWorker(id:String, implementations: WorkerImplementations) -> ServiceWorker {

        
        return ServiceWorker(id: "TEST", url: URL(string: "http://www.example.com/\(escapeID(id))")!, implementations: implementations, state: .activated, content: "")
    }

    static func createTestWorker(id: String, content: String) -> ServiceWorker {
        return ServiceWorker.createTestWorker(id: id, state: .activated, content: content)
    }
}
