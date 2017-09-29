import XCTest
@testable import ServiceWorker
import PromiseKit
import JavaScriptCore

class ConstructableFetchResponseTests: XCTestCase {

    func testManualTestResponseCreation() {

        let jsc = JSContext()!
        jsc.globalObject.setValue(ConstructableFetchResponse.self, forProperty: "Response")
        let resp = JSPromise.fromJSValue(jsc.evaluateScript("new Response(\"hello\").text()")!)
        resp
            .then { response -> Void in
                XCTAssertEqual(response!.value.toString(), "hello")
            }
            .assertResolves()
    }

    func testManualTextResponseCreationInWorker() {

        let sw = ServiceWorker.createTestWorker(id: self.name)

        sw.evaluateScript("""
            var response = new Response("hello");
            response.text()
            .then((text) => {
                return [text, response.status, response.url, response.headers.get('content-type')]
            })
        """)
            .then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }.then { response -> Void in
                let array = response!.value!.toArray()!
                XCTAssertEqual(array[0] as? String, "hello")
                XCTAssertEqual(array[1] as? Int, 200)
                XCTAssertEqual(array[2] as? String, "")
                XCTAssertEqual(array[3] as? String, "text/plain")
            }
            .assertResolves()
    }

    func testResponseConstructionOptions() {

        let sw = ServiceWorker.createTestWorker(id: self.name)

        sw.evaluateScript("""
            new Response("hello", {
                status: 201,
                statusText: "CUSTOM TEXT",
                headers: {
                    "X-Custom-Header":"blah",
                    "Content-Type":"text/custom-content"
                }
            })
        """)
            .then { jsVal in
                let response = jsVal!.toObjectOf(FetchResponseProxy.self) as! FetchResponseProxy
                XCTAssertEqual(response.status, 201)
                XCTAssertEqual(response.statusText, "CUSTOM TEXT")
                XCTAssertEqual(response.headers.get("X-Custom-Header"), "blah")
                XCTAssertEqual(response.headers.get("Content-Type"), "text/custom-content")
                return response.text()
            }
            .then { text -> Void in
                XCTAssertEqual(text, "hello")
            }
            .assertResolves()
    }

    func testResponseWithArrayBuffer() {

        let sw = ServiceWorker.createTestWorker(id: self.name)

        sw.evaluateScript("""
            let buffer = new Uint8Array([1,2,3,4]).buffer;
            new Response(buffer)
        """)
            .then { jsVal -> Promise<Data> in
                let response = jsVal!.toObjectOf(FetchResponseProxy.self) as! FetchResponseProxy
                return response.data()
            }
            .then { data -> Void in
                let array = [UInt8](data)
                XCTAssertEqual(array[0], 1)
                XCTAssertEqual(array[1], 2)
                XCTAssertEqual(array[2], 3)
                XCTAssertEqual(array[3], 4)
            }
            .assertResolves()
    }
}
