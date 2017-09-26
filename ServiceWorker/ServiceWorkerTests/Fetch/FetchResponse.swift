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

        FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
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

        FetchSession.default.fetch(request)
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
                "test": "value"
            ])
            res!.statusCode = 200
            return res
        }

        FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.json"))
            .then { response in
                response.json()
            }
            .then { obj -> Void in

                let json = obj as! [String: Any]

                XCTAssertEqual(json["test"] as! String, "value")
            }
            .assertResolves()
    }

    func testResponseInWorker() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }

        let sw = TestWorker(id: "TEST", state: .activated, url: TestWeb.serverURL, content: "")

        sw.evaluateScript("""
            fetch('\(TestWeb.serverURL.appendingPathComponent("/test.txt"))')
            .then(function(res) { return res.text() })
        """)
            .then { val in
                return JSPromise.fromJSValue(val!)
            }
            .then { val in
                XCTAssertEqual(val?.value.toString(), "THIS IS TEST CONTENT")
            }
            .assertResolves()
    }

    func testFetchResponseClone() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }

        FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res -> Promise<Void> in

                let clone = try res.clone()

                let cloneText = clone.text()

                let originalText = res.text()

                return when(fulfilled: [originalText, cloneText])
                    .then { results -> Void in

                        XCTAssertEqual(results.count, 2)
                        results.forEach { XCTAssertEqual($0, "THIS IS TEST CONTENT") }
                    }
            }
            .assertResolves()
    }

    func testDataResponse() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.dat", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in

            let d = Data(bytes: [1, 2, 3, 4, 254])
            let res = GCDWebServerDataResponse(data: d, contentType: "application/binary")
            res.statusCode = 200
            return res
        }

        FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.dat"))
            .then { res in
                res.data()
            }.then { data -> Void in

                data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
                    XCTAssertEqual(bytes[0], 1)
                    XCTAssertEqual(bytes[1], 2)
                    XCTAssertEqual(bytes[2], 3)
                    XCTAssertEqual(bytes[3], 4)
                    XCTAssertEqual(bytes[4], 254)
                }
            }
            .assertResolves()
    }

    func testArrayBufferResponse() {

        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.dat", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in

            let d = Data(bytes: [1, 2, 3, 4, 255])
            let res = GCDWebServerDataResponse(data: d, contentType: "application/binary")
            res.statusCode = 200
            return res
        }

        let sw = TestWorker(id: "TEST", state: .activated, url: TestWeb.serverURL, content: "")

        sw.evaluateScript("""
            fetch('\(TestWeb.serverURL.appendingPathComponent("/test.dat"))')
            .then(function(res) { return res.arrayBuffer() })
            .then(function(arrBuffer) {
            let arr = new Uint8Array(arrBuffer);

            return [arr[0],arr[1],arr[2],arr[3],arr[4]]
            })
        """)
            .then { val in
                return JSPromise.fromJSValue(val!)
            }.then { val -> Void in
                let arr = val?.value.toArray() as? [Int]

                XCTAssertEqual(arr?[0], 1)
                XCTAssertEqual(arr?[1], 2)
                XCTAssertEqual(arr?[2], 3)
                XCTAssertEqual(arr?[3], 4)
                XCTAssertEqual(arr?[4], 255)
            }
            .assertResolves()
    }

    func testResponseToFileDownload() {
        TestWeb.server!.addHandler(forMethod: "GET", path: "/test.txt", request: GCDWebServerRequest.self) { (_) -> GCDWebServerResponse? in
            let res = GCDWebServerDataResponse(text: "THIS IS TEST CONTENT")
            res!.statusCode = 200
            return res
        }

        FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res in
                res.internalResponse.fileDownload { localFile, _ in

                    // test that we can use async promises here

                    Promise<Void> { (fulfill: @escaping () -> Void, _: (Error) -> Void) in
                        DispatchQueue.global(qos: .background).async {

                            fulfill()
                        }
                    }
                    .then { () -> String in

                        return try String(contentsOfFile: localFile.path)
                    }
                }
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

        FetchSession.default.fetch(TestWeb.serverURL.appendingPathComponent("/test.txt"))
            .then { res in
                res.internalResponse.fileDownload { _, _ in

                    throw ErrorMessage("Oh no")
                }
            }
            .recover { error in
                XCTAssertEqual((error as? ErrorMessage)?.message, "Oh no")
            }
            .assertResolves()
    }
}
