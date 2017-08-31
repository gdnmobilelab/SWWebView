//
//  ServiceWorkerExtensions.swift
//  hybrid
//
//  Created by alastair.coote on 01/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

class ServiceWorkerTestDelegate: ServiceWorkerDelegate {

    static var storageURL: URL?

    internal var storageURL: URL {
        return ServiceWorkerTestDelegate.storageURL!
    }

    static func reset() {
        self.storageURL = nil
        self.importScripts = nil
    }

    static var importScripts: (([URL], ServiceWorker, @escaping (Error?, [String]?) -> Void) -> Void)?

    func importScripts(at: [URL], for worker: ServiceWorker, _ callback: @escaping (Error?, [String]?) -> Void) {
        ServiceWorkerTestDelegate.importScripts!(at, worker, callback)
    }

    static var instance = ServiceWorkerTestDelegate()
}

extension ServiceWorker {

    fileprivate static func escapeID(_ id: String) -> String {
        return id.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
    }

    static func createTestWorker(id: String, state: ServiceWorkerInstallState = .activated, content: String = "") -> ServiceWorker {
        let worker = ServiceWorker(id: id, url: URL(string: "http://www.example.com/\(escapeID(id)).js")!, state: state, content: content)
        worker.delegate = ServiceWorkerTestDelegate.instance
        return worker
    }

    static func createTestWorker(id: String) -> ServiceWorker {
        let worker = ServiceWorker(id: "TEST", url: URL(string: "http://www.example.com/\(escapeID(id))")!, state: .activated, content: "")
        worker.delegate = ServiceWorkerTestDelegate.instance
        return worker
    }

    static func createTestWorker(id: String, content: String) -> ServiceWorker {
        let worker = ServiceWorker.createTestWorker(id: id, state: .activated, content: content)
        worker.delegate = ServiceWorkerTestDelegate.instance
        return worker
    }
}
