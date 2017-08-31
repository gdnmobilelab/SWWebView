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

    let factory = WorkerRegistrationFactory(withWorkerFactory: WorkerFactory())

    func testContainerCreation() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        XCTAssertNoThrow(try {
            let testContainer = try ServiceWorkerContainer(forURL: URL(string: "https://www.example.com")!, withFactory: factory)
            XCTAssert(testContainer.url.absoluteString == "https://www.example.com")
        }())
    }

    func testGetRegistrations() {

        firstly { () -> Promise<Void> in
            let reg1 = try factory.create(scope: URL(string: "https://www.example.com/scope1")!)
            let reg2 = try factory.create(scope: URL(string: "https://www.example.com/scope2")!)
            let container = try ServiceWorkerContainer(forURL: URL(string: "https://www.example.com/scope3")!, withFactory: factory)
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
            _ = try factory.create(scope: URL(string: "https://www.example.com/scope1/")!)
            let reg1 = try factory.create(scope: URL(string: "https://www.example.com/scope1/scope2/")!)
            _ = try factory.create(scope: URL(string: "https://www.example.com/scope1/scope2/file2.html")!)
            let container = try ServiceWorkerContainer(forURL: URL(string: "https://www.example.com/scope1/scope2/file.html")!, withFactory: factory)
            return container.getRegistration()
                .then { registration -> Void in
                    XCTAssertEqual(registration, reg1)
                }
        }
        .assertResolves()
    }
}
