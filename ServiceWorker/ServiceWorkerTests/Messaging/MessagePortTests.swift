//
//  MessagePort.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import JavaScriptCore

class MessagePortTests: XCTestCase {

    func testSendingAMessage() {
        let portOne = SWMessagePort()
        let portTwo = SWMessagePort()

        portOne.targetPort = portTwo

        var fired = false
        let listener = portTwo.addEventListener("message") { (ev: ExtendableMessageEvent) in

            let dict = ev.data as! [String: Any]

            XCTAssertEqual(dict["hello"] as? String, "there")
            fired = true
        }

        portOne.postMessage([
            "hello": "there"
        ])

        portOne.start()

        XCTAssertTrue(fired)
    }

    func testAutoStartOnMessageSetter() {
        let portOne = SWMessagePort()
        let portTwo = SWMessagePort()

        portOne.targetPort = portTwo
        portTwo.targetPort = portOne

        let jsc = JSContext()!
        jsc.setObject(portTwo, forKeyedSubscript: "testPort" as NSCopying & NSObjectProtocol)

        jsc.evaluateScript("""
            var fireResponse = null
            testPort.onmessage = function(e) {
                fireResponse = e.data.hello;
            }
        """)

        portOne.postMessage(["hello": "there"])

        XCTAssertEqual(jsc.objectForKeyedSubscript("fireResponse")!.toString(), "there")
    }
}
