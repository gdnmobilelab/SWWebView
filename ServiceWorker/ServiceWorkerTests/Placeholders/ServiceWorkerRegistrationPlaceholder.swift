//
//  ServiceWorkerRegistrationPlaceholder.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

class ServiceWorkerRegistrationPlaceholder: ServiceWorkerRegistrationProtocol {
    func showNotification(title _: String) {
        Log.error?("Tried to show notification in placeholder registration")
    }
}
