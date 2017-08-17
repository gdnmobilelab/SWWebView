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

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.addStubs()
        let config = WKWebViewConfiguration()

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

        let swView = SWWebView(frame: self.view.frame, configuration: config)
        swView.serviceWorkerPermittedDomains.append("localhost:4567")

        self.view.addSubview(swView)

        var url = URLComponents(string: "sw://localhost:4567/tests.html")!
        URLCache.shared.removeAllCachedResponses()
        NSLog("Loading \(url.url!.absoluteString)")
        swView.load(URLRequest(url: url.url!))
    }

    func addStubs() {
        CommandBridge.routes["/ping"] = { task in

            let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
                "Content-Type": "application/json",
            ])
            task.didReceive(response!)
            task.didReceive("{\"pong\":true}".data(using: String.Encoding.utf8)!)
            task.didFinish()
        }

        CommandBridge.routes["/ping-with-body"] = { task in

            var responseText = "no body found"
            do {
                if task.request.httpBody != nil {
                    let obj = try JSONSerialization.jsonObject(with: task.request.httpBody!, options: []) as? AnyObject

                    responseText = obj!["value"]! as! String
                }

            } catch {
                fatalError("\(error)")
            }

            let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
                "Content-Type": "application/json",
            ])
            task.didReceive(response!)
            task.didReceive("{\"pong\":\"\(responseText)\"}".data(using: String.Encoding.utf8)!)
            task.didFinish()
        }

        CommandBridge.routes["/stream"] = { task in

            let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
            ])
            task.didReceive(response!)
            task.didReceive("test-event: {\"test\":\"hello\"}".data(using: String.Encoding.utf8)!)
            task.didReceive("test-event2: {\"test\":\"hello2\"}".data(using: String.Encoding.utf8)!)

            task.didFinish()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
