//
//  EmptyImportScriptsCallback.swift
//  ServiceWorker
//
//  Created by alastair.coote on 28/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

class EmptyImportScripts {
    static func callback(sw: ServiceWorker, url:[URL]) throws -> [String] {
        throw ErrorMessage("You must provide an importScripts implementation on ServiceWorker")
    }
}

