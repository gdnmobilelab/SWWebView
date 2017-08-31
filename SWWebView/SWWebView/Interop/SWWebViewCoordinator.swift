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
    let container:ServiceWorkerContainer
    var numUsing: Int
}

public class SWWebViewCoordinator : SWWebViewContainerDelegate {
    
    let workerFactory: WorkerFactory
    let registrationFactory: WorkerRegistrationFactory
    
    public init() {
        self.workerFactory = WorkerFactory()
        self.registrationFactory = WorkerRegistrationFactory(withWorkerFactory: self.workerFactory)
    }
    
    var inUseContainers: [SWWebView: [ContainerAndUsageNumber]] = [:]
    
    public func container(_ webview: SWWebView, createContainerFor url: URL) throws -> ServiceWorkerContainer {
        
        var containerArray = self.inUseContainers[webview] ?? {
            let newArray: [ContainerAndUsageNumber] = []
            self.inUseContainers[webview] = newArray
            return newArray
        }()
        
        if var alreadyExists = containerArray.first(where: { $0.container.url.absoluteString == url.absoluteString }){
            alreadyExists.numUsing += 1
            return alreadyExists.container
        }
        
        let newContainer = try ServiceWorkerContainer(forURL: url, withFactory: self.registrationFactory)
        let wrapper = ContainerAndUsageNumber(container: newContainer, numUsing: 1)
        containerArray.append(wrapper)
        return newContainer
    }
    
    public func container(_ webview: SWWebView, getContainerFor url: URL) -> ServiceWorkerContainer? {
        
        guard let containerDictionary = self.inUseContainers[webview] else {
            return nil
        }
        
        return containerDictionary.first(where: {$0.container.url.absoluteString == url.absoluteString})?.container
        
    }
    
    public func container(_ webview: SWWebView, freeContainer container: ServiceWorkerContainer) {
        
        guard var containerArray = self.inUseContainers[webview] else {
            Log.error?("Tried to remove a ServiceWorkerContainer that doesn't exist")
            return
        }
        
        guard let containerIndex = containerArray.index(where: {$0.container == container}) else {
            Log.error?("Tried to remove a ServiceWorkerContainer that doesn't exist")
            return
        }
        
        containerArray[containerIndex].numUsing -= 1
        
        if containerArray[containerIndex].numUsing == 0 {
            // If this is the only client using this container then we can safely dispose of it.
            containerArray.remove(at: containerIndex)
        }
        
        
    }
    
}
