import XCTest
@testable import ServiceWorker

class FetchEventTests: XCTestCase {

    func testRespondWithString() {

        let sw = ServiceWorker.createTestWorker(id: name, content: """
            self.addEventListener('fetch',(e) => {
                e.respondWith("hello");
            });
        """)

        let fetch = FetchEvent(type: "fetch")

        sw.dispatchEvent(fetch)
            .then {
                return fetch.resolve(in: sw)
            }
            .then { jsValue in
                XCTAssertEqual(jsValue.toString(), "hello")
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

        let fetch = FetchEvent(type: "fetch")

        sw.dispatchEvent(fetch)
            .then {
                return fetch.resolve(in: sw)
            }
            .then { jsValue in
                XCTAssertEqual(jsValue.toString(), "hello")
            }
            .assertResolves()
    }
}
