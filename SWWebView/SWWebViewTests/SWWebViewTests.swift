//
//  SWWebViewTests.swift
//  SWWebViewTests
//
//  Created by alastair.coote on 07/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import SWWebView
import WebKit

class SWWebViewTests: XCTestCase {

    override func setUp() {
        super.setUp()

        CommandBridge.routes["/ping"] = { task, data in

            let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
                "Content-Type": "application/json",
            ])
            task.didReceive(response!)
            task.didReceive("{\"pong\":true}".data(using: String.Encoding.utf8)!)
            task.didFinish()
        }
        
        CommandBridge.routes["/ping-with-body"] = { task, data in

            var responseText = "no body found"
            do {
                if data != nil {
                    let obj = try JSONSerialization.jsonObject(with: data!, options: []) as? AnyObject
                
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

        CommandBridge.routes["/stream"] = { task, data in

            let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
                "Content-Type": "text/event-stream",
            ])
            task.didReceive(response!)
            task.didReceive("test-event: {\"test\":\"hello\"}".data(using: String.Encoding.utf8)!)
            task.didFinish()
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.

        CommandBridge.routes.removeValue(forKey: "/ping")
        CommandBridge.routes.removeValue(forKey: "/ping-with-body")
        CommandBridge.routes.removeValue(forKey: "/stream")
        
        super.tearDown()
    }

    func testJSTests() {

        let config = WKWebViewConfiguration()

        class Reporter: NSObject, WKScriptMessageHandler {

            let exp = XCTestExpectation(description: "All JS tests complete")

            func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {

                let obj = message.body as! [String: AnyObject]

                if obj["log"] as? Bool == true {
                    let msg = obj["message"] as! String
                    NSLog(msg)
                    return
                }

                if obj["done"] as? Bool == true {
                    self.exp.fulfill()
                } else {
                    let title = obj["test"] as! String
                    let error = obj["error"] as? String
                    if error != nil {
                        NSLog("JS ERROR: \(error!)")
                        XCTFail("\(title): \(error!)")
                    }
                }
            }
        }

        let testReporter = Reporter()

        config.userContentController.add(testReporter, name: "testReporter")

        let sw = SWWebView(frame: CGRect(x: 0, y: 0, width: 0, height: 0), configuration: config)
        sw.serviceWorkerPermittedDomains = [
            "www.example.com",
        ]

        let pathToJS = Bundle(for: SWWebViewTests.self).bundleURL
            .appendingPathComponent("js-tests", isDirectory: true)
            .appendingPathComponent("tests.js")

        var jsRuntimeSource: String?

        do {
            jsRuntimeSource = try String(contentsOf: pathToJS)
        } catch {
            XCTFail("\(error)")
        }

        let wrapped = SWWebView.wrapScriptInWebviewSettings(jsRuntimeSource!)

        sw.loadHTMLString("<html><body><script></script></body></html>", baseURL: URL(string: "sw://www.example.com/"))

        sw.evaluateJavaScript(wrapped, completionHandler: { _, err in
            if err != nil {
                XCTFail("\(err!)")
            }
        })

        wait(for: [testReporter.exp], timeout: 1000)
    }
}
