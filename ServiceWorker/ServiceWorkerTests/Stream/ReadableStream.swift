//
//  ReadableStream.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 07/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import PromiseKit

class ReadableStreamTests: XCTestCase {

    func testReadableStreamRead() {

        var controller: ReadableStreamController?

        let str = ReadableStream(start: { c in
            controller = c
        })
        let expect = expectation(description: "Stream reads")

        str.read { _ in
            expect.fulfill()
        }

        XCTAssertNoThrow(try controller!.enqueue("TEST".data(using: String.Encoding.utf8)!))

        wait(for: [expect], timeout: 1)
    }

    func testReadableStreamEnqueueAfterClose() {

        let str = ReadableStream()
        XCTAssertNoThrow(try str.controller!.enqueue("TEST".data(using: String.Encoding.utf8)!))
        str.close()
        XCTAssertThrowsError(try str.controller!.enqueue("TEST".data(using: String.Encoding.utf8)!))
    }

    func testMultipleQueues() {

        let str = ReadableStream()
        XCTAssertNoThrow(try str.controller!.enqueue("TEST".data(using: String.Encoding.utf8)!))
        XCTAssertNoThrow(try str.controller!.enqueue("THIS".data(using: String.Encoding.utf8)!))

        str.read { read in
            let returnString = String(data: read.value!, encoding: String.Encoding.utf8)
            XCTAssert(returnString == "TESTTHIS")
        }
    }

    func testDone() {

        let str = ReadableStream()
        XCTAssertNoThrow(try str.controller!.enqueue("TEST".data(using: String.Encoding.utf8)!))
        str.close()
        str.read { read in
            XCTAssert(read.done == false)
        }
        str.read { read in
            XCTAssert(read.done == true)
        }
    }
    
    func testInputStream() {
        
        let testContent = "ABCDE"
        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory() + "/test.txt")
        
        
        firstly { () -> Promise<Void> in
            try testContent.write(to: targetURL, atomically: false, encoding: .utf8)
            
            let stream = InputStream(url: targetURL)!
            let readableStream = ReadableStream.fromInputStream(stream: stream, bufferSize: 2)
            
            return readableStream.read()
                .then { result -> Promise<StreamReadResult> in
                    
                    XCTAssertEqual(String(data: result.value!, encoding: .utf8), "AB")
                    return readableStream.read()
            }
                .then { result -> Promise<StreamReadResult> in
                    XCTAssertEqual(String(data: result.value!, encoding: .utf8), "CD")
                    return readableStream.read()
            }
                .then { result -> Promise<StreamReadResult> in
                    XCTAssertEqual(String(data: result.value!, encoding: .utf8), "E")
                    return readableStream.read()
    
            }
                .then { result -> Void in
                    XCTAssertEqual(result.done, true)
            }
            
        }
        .assertResolves()
        
        
    }
}
