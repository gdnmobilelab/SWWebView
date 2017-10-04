//
//  ServiceWorkerExtensions.swift
//  hybrid
//
//  Created by alastair.coote on 01/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
@testable import ServiceWorker

class StaticContentDelegate : NSObject, ServiceWorkerDelegate {
    
    func serviceWorkerGetDomainStoragePath(_ worker: ServiceWorker) throws -> URL {
        return StaticContentDelegate.storageURL
            .appendingPathComponent("domains", isDirectory: true)
            .appendingPathComponent(worker.url.host!, isDirectory: true)
    }
    
    static let storageURL = URL(fileURLWithPath: NSTemporaryDirectory())
    
    func serviceWorker(_: ServiceWorker, importScript: URL, _ callback: @escaping (Error?, String?) -> Void) {
        callback(ErrorMessage("not implemented"), nil)
    }
    
    func serviceWorkerGetScriptContent(_: ServiceWorker) throws -> String {
        return self.script
    }
    
    func getCoreDatabaseURL() -> URL {
        return StaticContentDelegate.storageURL.appendingPathComponent("core.db")
    }
    
    
    let script:String
    
    init(script:String) {
        self.script = script
    }
}

class TestWorker : ServiceWorker {
    
    fileprivate let staticDelegate: ServiceWorkerDelegate
    
    init(id: String, state: ServiceWorkerInstallState = .activated, url: URL? = nil, content: String = "") {
        self.staticDelegate = StaticContentDelegate(script: content)
        
        let urlToUse = url ?? URL(string: "http://www.example.com/\(ServiceWorker.escapeID(id)).js")!
        
        super.init(id: id, url: urlToUse, state: state)
        self.delegate = self.staticDelegate
    }
    
}

extension ServiceWorker {
    
    fileprivate static func escapeID(_ id: String) -> String {
        return id.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
    }

    static func createTestWorker(id: String, state: ServiceWorkerInstallState = .activated, content: String = "") -> ServiceWorker {
        return TestWorker(id: id, state: state, content: content)
    }

    static func createTestWorker(id: String) -> ServiceWorker {
        return TestWorker(id: id, state: .activated)
    }

    static func createTestWorker(id: String, content: String) -> ServiceWorker {
        return TestWorker(id: id, state: .activated, content: content)
    }
}
