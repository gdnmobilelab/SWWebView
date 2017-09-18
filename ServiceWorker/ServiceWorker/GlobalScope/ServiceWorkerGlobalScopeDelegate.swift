//
//  ServiceWorkerGlobalScopeDelegate.swift
//  ServiceWorker
//
//  Created by alastair.coote on 30/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc protocol ServiceWorkerGlobalScopeDelegate {
    func importScripts(urls: [URL]) throws
    func openWebSQLDatabase(name: String) throws -> WebSQLDatabase
}
