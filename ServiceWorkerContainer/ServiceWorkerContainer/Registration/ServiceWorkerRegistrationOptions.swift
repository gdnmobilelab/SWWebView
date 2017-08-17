//
//  ServiceWorkerRegistrationOptions.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

public struct ServiceWorkerRegistrationOptions {
    public let scope: URL?

    public init(scope: URL?) {
        self.scope = scope
    }
}
