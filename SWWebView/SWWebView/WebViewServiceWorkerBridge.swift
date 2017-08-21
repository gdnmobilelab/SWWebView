//
////  WebViewContainerPair.swift
////  SWWebView
////
////  Created by alastair.coote on 08/08/2017.
////  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
////
//
//import Foundation
//import WebKit
//import ServiceWorkerContainer
//import ServiceWorker
//
//class WebViewServiceWorkerBridge {
//
//    let target: SWWebView
//
//    // we use strings here because URL equality is weird in Swift. Strings are straightfoward.
//    var activeURLs: [String] = []
//
//    // we separate active URLs and active containers because there might be more than
//    // one frame sharing the same container.
//    var activeContainers = Set<ServiceWorkerContainer>()
//
//    init(for webView: SWWebView) {
//        self.target = webView
//    }
//
//    // When the webview loads a new page or new frame, we fire this function to see
//    // if we need to create a ServiceWorkerContainer for it or not.
//    func addActive(url: URL) {
//
//        if url.host == nil || self.target.serviceWorkerPermittedDomains.contains(url.host!) == false {
//            // we only care about worker domains
//            return
//        }
//
//        self.activeURLs.append(url.absoluteString)
//
//        if self.activeContainers.first(where: { $0.containerURL.absoluteString == url.absoluteString }) == nil {
//
//            // if this is the first time this URL has been added to the view, we should
//            // get the container and add it to our collection. Although ServiceWorkerContainer
//            // keeps it's own references, they are weak, and we want to establish a strong
//            // reference so that the container isn't killed while the WebView is alive.
//
//            let newContainer = try ServiceWorkerContainer.get(for: url)
//            self.activeContainers.insert(newContainer)
//        }
//    }
//
//    func removeActive(url: URL) {
//
//        // index returns the first index it finds, which is what we want - we only
//        // want to remove one instance of the URL if there are many.
//
//        let existingIndex = self.activeURLs.index(of: url.absoluteString)
//        if existingIndex == nil {
//            Log.error?("Tried to remove a URL that isn't in the list of active URLs!")
//            // putting in a fatal error because this shouldn't happen - better to detect
//            // it when developing.
//            fatalError()
//        }
//
//        self.activeURLs.remove(at: existingIndex!)
//
//        // if there are now no remaining instances of this URL, we can remove the
//        // container from our collection.
//        if self.activeURLs.index(of: url.absoluteString) == nil {
//
//            let existingIndex = self.activeContainers.index(where: { $0.containerURL.absoluteString == url.absoluteString })
//            if existingIndex == nil {
//                Log.error?("ServiceWorkerContainer didn't exist when it should")
//                fatalError()
//            }
//            self.activeContainers.remove(at: existingIndex!)
//        }
//    }
//}

