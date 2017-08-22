//
//  WorkerInstallationError.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 22/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

public struct WorkerInstallationError {
    public let worker:ServiceWorker
    public let container: ServiceWorkerContainer
    public let error:Error
}
