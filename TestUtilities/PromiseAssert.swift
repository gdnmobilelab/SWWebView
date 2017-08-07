//
//  PromiseAssert.swift
//  hybrid
//
//  Created by alastair.coote on 28/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit
import XCTest

extension Promise {
    func assertResolves() {

        let expect = XCTestExpectation(description: "Promise resolves")
        let waiter = XCTWaiter()
        then { _ in
            expect.fulfill()
        }.catch { error in
            XCTFail("\(error)")
            expect.fulfill()
        }

        waiter.wait(for: [expect], timeout: 100)
    }

    func assertRejects() {

        let expect = XCTestExpectation(description: "Promise resolves")

        then { _ in
            XCTFail("Promise should reject")
        }.catch { _ in
            expect.fulfill()
        }

        let waiter = XCTWaiter()
        waiter.wait(for: [expect], timeout: 1)
    }
}
