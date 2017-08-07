//
//  DummyServiceWorkerRegistration.swift
//  ServiceWorker
//
//  Created by alastair.coote on 16/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public class DummyServiceWorkerRegistration: NSObject, ServiceWorkerRegistrationProtocol {

    public func showNotification(title _: String) {
        NSLog("Shown")
    }
}
