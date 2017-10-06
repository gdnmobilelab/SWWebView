import XCTest
@testable import ServiceWorker

class FetchEventTests: XCTestCase {

    func testRespondWithString() {

        let sw = ServiceWorker.createTestWorker(id: name, content: """
            self.addEventListener('fetch',(e) => {
                e.respondWith(new Response("hello"));
            });
        """)

        let request = FetchRequest(url: URL(string: "https://www.example.com")!)

        let fetch = FetchEvent(request: request)

        sw.dispatchEvent(fetch)
            .then {
                return try fetch.resolve(in: sw)
            }
            .then { res in
                return res!.text()
            }
            .then { responseText in
                XCTAssertEqual(responseText, "hello")
            }
            .assertResolves()
    }

    func testRespondWithPromise() {

        let sw = ServiceWorker.createTestWorker(id: name, content: """
            self.addEventListener('fetch',(e) => {
                e.respondWith(new Promise((fulfill) => {
                    fulfill(new Response("hello"))
                }));
            });
        """)

        let request = FetchRequest(url: URL(string: "https://www.example.com")!)

        let fetch = FetchEvent(request: request)

        sw.dispatchEvent(fetch)
            .then {
                return try fetch.resolve(in: sw)
            }
            .then { res in
                return res!.text()
            }
            .then { responseText in
                XCTAssertEqual(responseText, "hello")
            }
            .assertResolves()
    }
}
