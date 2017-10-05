import XCTest
@testable import ServiceWorker

class FetchEventTests: XCTestCase {

    func testRespondWithString() {

        let sw = ServiceWorker.createTestWorker(id: name, content: """
            self.addEventListener('fetch',(e) => {
                e.respondWith("hello");
            });
        """)

        let request = FetchRequest(url: URL(string: "https://www.example.com")!)

        let fetch = FetchEvent(request: request)

        sw.dispatchEvent(fetch)
            .then {
                return try fetch.resolve(in: sw)
            }
            .then { jsValue in
                XCTAssertEqual(jsValue?.value.toString(), "hello")
            }
            .assertResolves()
    }

    func testRespondWithPromise() {

        let sw = ServiceWorker.createTestWorker(id: name, content: """
            self.addEventListener('fetch',(e) => {
                e.respondWith(new Promise((fulfill) => {
                    fulfill("hello")
                }));
            });
        """)

        let request = FetchRequest(url: URL(string: "https://www.example.com")!)

        let fetch = FetchEvent(request: request)

        sw.dispatchEvent(fetch)
            .then {
                return try fetch.resolve(in: sw)
            }
            .then { jsValue in
                XCTAssertEqual(jsValue?.value.toString(), "hello")
            }
            .assertResolves()
    }
}
