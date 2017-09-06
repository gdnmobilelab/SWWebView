//
//  SWWebViewCoordinator.swift
//  SWWebView
//
//  Created by alastair.coote on 31/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer
import ServiceWorker

/// Ideally we would have a separate container for each usage, but we can't detect from
/// the WKURLSchemeHandler which instance of a URL is sending a command. So instead, we
/// have them share a container between them.
struct ContainerAndUsageNumber {
    let webview: SWWebView
    let container: ServiceWorkerContainer
    var numUsing: Int
}

public class SWWebViewCoordinator: SWWebViewContainerDelegate, ServiceWorkerClientsDelegate {

    let workerFactory: WorkerFactory
    let registrationFactory: WorkerRegistrationFactory

    public init() {
        self.workerFactory = WorkerFactory()
        self.registrationFactory = WorkerRegistrationFactory(withWorkerFactory: self.workerFactory)
        self.workerFactory.clientsDelegateProvider = self
    }

    var inUseContainers: [ContainerAndUsageNumber] = []

    public func container(_ webview: SWWebView, createContainerFor url: URL) throws -> ServiceWorkerContainer {

        if var alreadyExists = self.inUseContainers.first(where: { $0.webview == webview && $0.container.url.absoluteString == url.absoluteString }) {
            alreadyExists.numUsing += 1
            Log.info?("Returning existing ServiceWorkerContainer for \(url.absoluteString). It has \(alreadyExists.numUsing) other clients")
            return alreadyExists.container
        }

        let newContainer = try ServiceWorkerContainer(forURL: url, withFactory: self.registrationFactory)
        let wrapper = ContainerAndUsageNumber(webview: webview, container: newContainer, numUsing: 1)
        self.inUseContainers.append(wrapper)

        Log.info?("Returning new ServiceWorkerContainer for \(url.absoluteString).")
        return newContainer
    }

    public func container(_ webview: SWWebView, getContainerFor url: URL) -> ServiceWorkerContainer? {

        return self.inUseContainers.first(where: { $0.webview == webview && $0.container.url.absoluteString == url.absoluteString })?.container
    }

    public func container(_ webview: SWWebView, freeContainer container: ServiceWorkerContainer) {

        guard let containerIndex = self.inUseContainers.index(where: { $0.webview == webview && $0.container == container }) else {
            Log.error?("Tried to remove a ServiceWorkerContainer that doesn't exist")
            return
        }

        self.inUseContainers[containerIndex].numUsing -= 1

        let url = self.inUseContainers[containerIndex].container.url

        if self.inUseContainers[containerIndex].numUsing == 0 {
            // If this is the only client using this container then we can safely dispose of it.
            Log.info?("Deleting existing ServiceWorkerContainer for \(url.absoluteString).")
            self.inUseContainers.remove(at: containerIndex)
        } else {
            Log.info?("Released link to ServiceWorkerContainer for \(url.absoluteString). It has \(self.inUseContainers[containerIndex].numUsing) remaining clients")
        }
    }

    public func clientsClaim(_ worker: ServiceWorker, _ cb: (Error?) -> Void) {

        if worker.state != .activated && worker.state != .activating {
            cb(ErrorMessage("Service worker can only claim clients when in activated or activating state"))
            return
        }

        guard let registration = worker.registration else {
            cb(ErrorMessage("ServiceWorker must have a registration to claim clients"))
            return
        }

        let scopeString = registration.scope.absoluteString

        let clientsInScope = self.inUseContainers.filter { client in

            if client.container.url.absoluteString.hasPrefix(scopeString) == false {
                // must fall within our scope
                return false
            }

            guard let ready = client.container.readyRegistration else {
                // if it has no ready registration we will always claim it.
                return true
            }

            // Otherwise, we need to check - is the current scope more specific than ours?
            // If it is, we don't claim.
            return ready.scope.absoluteString.count <= scopeString.count
        }

        clientsInScope.forEach { client in
            client.container.claim(by: worker)
        }
        cb(nil)
    }
}
