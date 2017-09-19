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

        let sw = ServiceWorker.createTestWorker(id: name)

        return sw.evaluateScript("""
            var didFire = false;
            self.addEventListener('test', function() {
                didFire = true;
            });
            self.dispatchEvent(new Event('test'));
            didFire;
        """)

            .then { didFire -> Void in
                XCTAssertEqual(didFire!.toBool(), true)
            }
            .assertResolves()
    }

    func testShouldRemoveEventListeners() {

        let testEvents = EventTarget()

        let sw = ServiceWorker.createTestWorker(id: name)

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

    func testShouldFireSwiftEvents() {

        let testEvents = EventTarget()
        var fired = false

        let testEvent = Event(type: "test")

        testEvents.addEventListener("test") { (ev: Event) in
            XCTAssertEqual(ev, testEvent)
            fired = true
        }

        testEvents.dispatchEvent(testEvent)

        XCTAssertTrue(fired)
    }
}
