//
//  FetchResponse.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 14/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import GCDWebServers
import Gzip
import JavaScriptCore
import PromiseKit

class FetchResponseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        TestWeb.createServer()
    }

    override func tearDown() {
        TestWeb.destroyServer()
        super.tearDown()
    }

    func testFetchResponseText() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }

        FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res in
                res.text()
            }
            .then { str -> Void in
                XCTAssertEqual(str, "THIS IS TEST CONTENT")
                NSLog("End fetch")
            }
            .assertResolves()
    }

    func testGzipResponse() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test-gzip.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in

            var res: GCDWebServerDataResponse?

            do {
                let gzipped = try "THIS IS TEST CONTENT".data(using: String.Encoding.utf8)!.gzipped()

                res = GCDWebServerDataResponse(data: gzipped, contentType: "text/plain")
                res!.setValue("gzip", forAdditionalHeader: "Content-Encoding")
                res!.statusCode = 200

            } catch {
                XCTFail(String(describing: error))
            }
            return res
        }

        let request = FetchRequest(url: TestWeb.serverURL.appendingPathComponent("/test-gzip.txt"))

        FetchOperation.fetch(request)
            .then { response -> Promise<Void> in
                let lengthInHeader = response.headers.get("Content-Length")
                XCTAssert(lengthInHeader == "20")

                return response.text()
                    .then { text -> Void in
                        XCTAssertEqual(text, "THIS IS TEST CONTENT")
                    }
            }.assertResolves()
    }

    func testFetchResponseJSON() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.json", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(jsonObject: [
                "test": "value",
            ])
            res!.statusCode = 200
            return res
        }
        let expectResponse = expectation(description: "Response body is received")

        FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.json").absoluteString) { err, res in
            XCTAssert(err == nil)
            res!.json { err, obj in

                XCTAssert(err == nil)

                let json = obj as! [String: Any]

                XCTAssertEqual(json["test"] as! String, "value")
                expectResponse.fulfill()
            }
        }

        wait(for: [expectResponse], timeout: 1)
    }

    func testResponseInJSContext() {

        let context = JSContext()!

        FetchOperation.addToJSContext(context: context)

        let expectResponse = expectation(description: "Response body is received via JS")

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }

        let promise = context.evaluateScript("""
            fetch('\(TestWeb.serverURL.appendingPathComponent("/test.txt"))')
            .then(function(res) { return res.text() })
        """)!

        JSPromise.resolve(promise) { err, val in
            XCTAssert(err == nil)
            XCTAssertEqual(val!.toString(), "THIS IS TEST CONTENT")
            expectResponse.fulfill()
        }

        wait(for: [expectResponse], timeout: 1)
    }

    func testFetchResponseClone() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }

        FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res -> Promise<Void> in
         
                var clone: FetchResponseProtocol?
                XCTAssertNoThrow(clone = try res.clone())
                
                let cloneText = clone!.text()
                    .then { text in
                         XCTAssertEqual(text, "THIS IS TEST CONTENT")
                }
                
                let originalText = res.text()
                    .then { text in
                        XCTAssertEqual(text, "THIS IS TEST CONTENT")
                }
                
                return when(fulfilled: [cloneText, originalText])
                
        }
        .assertResolves()
       
    }

    func testArrayBufferResponse() {

        let context = JSContext()!

        FetchOperation.addToJSContext(context: context)

        let expectResponse = expectation(description: "Response body is received via JS")

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.dat", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in

            let d = Data(bytes: [1, 2, 3, 4, 255])
            //            d.append(contentsOf: [1,2,3,4,255])
            let res = GCDWebServerDataResponse(data: d, contentType: "application/binary")
            res.statusCode = 200
            return res
        }

        let promise = context.evaluateScript("""
        fetch('\(TestWeb.serverURL.appendingPathComponent("/test.dat"))')
        .then(function(res) { return res.arrayBuffer() })
        .then(function(arrBuffer) {
            let arr = new Uint8Array(arrBuffer);
            return [arr[0],arr[1],arr[2],arr[3],arr[4]]
        })
        """)!

        JSPromise.resolve(promise) { _, val in

            let arr = val!.toArray() as! [Int]

            XCTAssertEqual(arr[0], 1)
            XCTAssertEqual(arr[1], 2)
            XCTAssertEqual(arr[2], 3)
            XCTAssertEqual(arr[3], 4)
            XCTAssertEqual(arr[4], 255)

            //            XCTAssert(err == nil)
            //            XCTAssertEqual(val!.toString(),"THIS IS TEST CONTENT")
            expectResponse.fulfill()
        }

        wait(for: [expectResponse], timeout: 100)
    }
    
    func testResponseToFileDownload() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }
        
        FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res in
                return res.internalResponse.fileDownload(withDownload: { localURL in
                    
                    // test that we can use async promises here
                    
                    return Promise<Void> { (fulfill: @escaping () -> Void, reject: (Error) -> Void) in
                        DispatchQueue.global(qos: .background).async {
                            
                            fulfill()
                        }
                    }
                        .then { () -> String in
                            
                            return try String(contentsOfFile: localURL.path)
                    }
                })
            }
            .then { contents in
                XCTAssertEqual(contents, "THIS IS TEST CONTENT")
            }
            .assertResolves()
    }
    
    func testResponseToFileDownloadHandlesErrors() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }
        
        FetchOperation.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res in
                return res.internalResponse.fileDownload(withDownload: { localURL in
                    
                    throw ErrorMessage("Oh no")
                    
                })
            }
            .recover { error in
                XCTAssertEqual((error as? ErrorMessage)?.message, "Oh no")
            }
            .assertResolves()
    }
}
