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
        
        CommandBridge.routes["/ping"] = { task in
            
            let response = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [
                "Content-Type": "application/json"
                ])
            task.didReceive(response!)
            task.didReceive("{\"pong\":true}".data(using: String.Encoding.utf8)!)
            task.didFinish()
            
        }
        
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        CommandBridge.routes.removeValue(forKey: "/ping")
        
        super.tearDown()
    }
    
 
    func testJSTests() {
        
        let config = WKWebViewConfiguration()
        
        class Reporter : NSObject, WKScriptMessageHandler {
            
            let exp = XCTestExpectation(description: "All JS tests complete")
            
            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                
                let obj = message.body as! [String: AnyObject]
                
                if obj["done"] as? Bool == true {
                     exp.fulfill()
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
            "www.example.com"
        ]
        
        let pathToJS = Bundle(for: SWWebViewTests.self).bundleURL
            .appendingPathComponent("js-tests", isDirectory: true)
            .appendingPathComponent("tests.js")
        
        var jsRuntimeSource:String? = nil
        
        do {
            jsRuntimeSource = try String(contentsOf: pathToJS)
        } catch {
            XCTFail("\(error)")
        }
        
        let wrapped = SWWebView.wrapScriptInWebviewSettings(jsRuntimeSource!)
        
        sw.loadHTMLString("<html><body></body></html>", baseURL: URL(string: "sw://www.example.com/"))
        
        
        sw.evaluateJavaScript(wrapped, completionHandler: { val, err in
            if err != nil {
                XCTFail("\(err!)")
            }
        })
        
        
        wait(for: [testReporter.exp], timeout: 1000)
        
    }
    

    
}
