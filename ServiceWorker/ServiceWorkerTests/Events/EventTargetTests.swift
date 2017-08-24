//
//  EventTargetTests.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import JavaScriptCore

class EventTargetTests: XCTestCase {

    func testShouldFireEvents() {

        let testEvents = EventTarget()

        let sw = ServiceWorker.createTestWorker()

        let expect = expectation(description: "Code ran")

        sw.withJSContext { context in
            context.globalObject.setValue(testEvents, forProperty: "testEvents")
        }
        .then {
            return sw.evaluateScript("""
                var didFire = false;
                testEvents.addEventListener('test', function() {
                    didFire = true;
                });
                testEvents.dispatchEvent(new Event('test'));
                didFire;
            """)
        }
        .then { didFire -> Void in
            XCTAssertEqual(didFire!.toBool(), true)
            expect.fulfill()
        }
        .catch { error -> Void in
            XCTFail("\(error)")
        }

        wait(for: [expect], timeout: 1)
    }

    func testShouldRemoveEventListeners() {

        let testEvents = EventTarget()

        let sw = ServiceWorker.createTestWorker()

        let expect = expectation(description: "Code ran")

        sw.withJSContext { context in
            context.globalObject.setValue(testEvents, forProperty: "testEvents")
        }
        .then {
            return sw.evaluateScript("""
                var didFire = false;
                function trigger() {
                    didFire = true;
                }
                testEvents.addEventListener('test', trigger);
                testEvents.removeEventListener('test', trigger);
                testEvents.dispatchEvent(new Event('test'));
                didFire;
            """)
        }
        .then { didFire -> Void in
            XCTAssertEqual(didFire!.toBool(), false)
            expect.fulfill()
        }
        .catch { error -> Void in
            XCTFail("\(error)")
        }

        wait(for: [expect], timeout: 1)
    }
}
