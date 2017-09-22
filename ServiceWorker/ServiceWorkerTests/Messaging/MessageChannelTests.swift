//
//  MessageChannelTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import JavaScriptCore

class MessageChannelTests: XCTestCase {

    func testMessageChannelInJS() {
        let channel = MessageChannel()
        let jsc = JSContext()!
        jsc.setObject(channel, forKeyedSubscript: "testChannel" as (NSCopying & NSObjectProtocol)!)

        jsc.evaluateScript("""
            var didFire = false;
            testChannel.port2.onmessage = function() {
                didFire = true
            }
            testChannel.port1.postMessage("hi");
        """)

        XCTAssertTrue(jsc.objectForKeyedSubscript("didFire").toBool())
    }
}
