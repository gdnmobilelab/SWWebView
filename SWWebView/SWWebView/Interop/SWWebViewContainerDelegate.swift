//
//  SWWebViewContainerDelegate.swift
//  SWWebView
//
//  Created by alastair.coote on 31/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorkerContainer
import ServiceWorker

@objc public protocol SWWebViewContainerDelegate {

    @objc func container(_: SWWebView, getContainerFor: URL) -> ServiceWorkerContainer?
    @objc func container(_: SWWebView, createContainerFor: URL) throws -> ServiceWorkerContainer
    @objc func container(_: SWWebView, freeContainer: ServiceWorkerContainer)
}
