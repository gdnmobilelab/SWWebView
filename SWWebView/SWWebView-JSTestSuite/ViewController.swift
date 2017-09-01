//
//  ViewController.swift
//  SWWebView-JSTestSuite
//
//  Created by alastair.coote on 11/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import UIKit
import SWWebView
import WebKit
import GCDWebServers
import ServiceWorkerContainer
import ServiceWorker
import PromiseKit

class ViewController: UIViewController {

    var coordinator: SWWebViewCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.addStubs()
        let config = WKWebViewConfiguration()

        Log.info = { NSLog($0) }

        CoreDatabase.dbDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("testapp-db", isDirectory: true)

        do {
            if FileManager.default.fileExists(atPath: CoreDatabase.dbDirectory!.path) {
                try FileManager.default.removeItem(at: CoreDatabase.dbDirectory!)
            }
            try FileManager.default.createDirectory(at: CoreDatabase.dbDirectory!, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError()
        }

        let headerScript = WKUserScript(source: "var swwebviewSettings = \(SWWebView.javascriptConfigDictionary);", injectionTime: .atDocumentStart, forMainFrameOnly: false)

        config.userContentController.addUserScript(headerScript)

        self.coordinator = SWWebViewCoordinator()

        let swView = SWWebView(frame: self.view.frame, configuration: config)
        swView.serviceWorkerPermittedDomains.append("localhost:4567")
        swView.containerDelegate = self.coordinator!
        self.view.addSubview(swView)

        var url = URLComponents(string: "sw://localhost:4567/tests.html")!
        URLCache.shared.removeAllCachedResponses()
        NSLog("Loading \(url.url!.absoluteString)")
        swView.load(URLRequest(url: url.url!))
    }

    func addStubs() {
        SWWebViewBridge.routes["/ping"] = { _, _ in

            Promise(value: [
                "pong": true,
            ])
        }

        SWWebViewBridge.routes["/ping-with-body"] = { _, json in

            var responseText = json?["value"] as? String ?? "no body found"

            return Promise(value: [
                "pong": responseText,
            ])
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
