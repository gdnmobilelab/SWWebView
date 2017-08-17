//
//  ServiceWorkerContainerTests.swift
//  ServiceWorkerContainerTests
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorkerContainer
import PromiseKit

class ServiceWorkerContainerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoreDatabase.clearForTests()

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testContainerCreation() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let testContainer = ServiceWorkerContainer(forURL: URL(string: "https://www.example.com")!)

        XCTAssert(testContainer.containerURL.absoluteString == "https://www.example.com")
    }

    func testGetRegistrations() {

        firstly { () -> Promise<Void> in
            let reg1 = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com/scope1")!)
            let reg2 = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com/scope2")!)
            let container = ServiceWorkerContainer.get(for: URL(string: "https://www.example.com/scope3")!)
            return container.getRegistrations()
                .then { registrations -> Void in
                    XCTAssertEqual(registrations.count, 2)
                    XCTAssertEqual(registrations[0], reg1)
                    XCTAssertEqual(registrations[1], reg2)
                }
        }
        .assertResolves()
    }

    func testGetRegistration() {
        firstly { () -> Promise<Void> in
            _ = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com/scope1/")!)
            let reg1 = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com/scope1/scope2/")!)
            _ = try ServiceWorkerRegistration.create(scope: URL(string: "https://www.example.com/scope1/scope2/file2.html")!)
            let container = ServiceWorkerContainer.get(for: URL(string: "https://www.example.com/scope1/scope2/file.html")!)
            return container.getRegistration()
                .then { registration -> Void in
                    XCTAssertEqual(registration, reg1)
                }
        }
        .assertResolves()
    }
}
