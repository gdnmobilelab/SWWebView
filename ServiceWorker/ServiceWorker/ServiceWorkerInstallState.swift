//
//  ServiceWorkerInstallState.swift
//  ServiceWorker
//
//  Created by alastair.coote on 14/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

/// The various states a Service Worker can exist in. As outlined in: https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorker/state
///
/// - Downloading: Isn't in the spec, but we use it when we are streaming the download of the JS
/// - Installing: The worker is currently in the process of installing
/// - Installed: The worker has successfully installed and is awaiting activation
/// - Activating: The worker is currently in the process of activating
/// - Activated: The worker is activated and ready to receive events and messages
/// - Redundant: The worker has either failed to install or has been superseded by a new version of the worker.
@objc public enum ServiceWorkerInstallState: Int {
    case downloading = 0
    case installing = 1
    case installed = 2
    case activating = 3
    case activated = 4
    case redundant = 5
}
