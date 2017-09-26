import Foundation

/// The various states a Service Worker can exist in. As outlined in: https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorker/state
///
/// - Downloading: Isn't in the spec, but we use it when we are streaming the download of the JS
/// - Installing: The worker is currently in the process of installing
/// - Installed: The worker has successfully installed and is awaiting activation
/// - Activating: The worker is currently in the process of activating
/// - Activated: The worker is activated and ready to receive events and messages
/// - Redundant: The worker has either failed to install or has been superseded by a new version of the worker.
public enum ServiceWorkerInstallState: String {
    //    case downloading = "downloading"
    case installing
    case installed
    case activating
    case activated
    case redundant
}
