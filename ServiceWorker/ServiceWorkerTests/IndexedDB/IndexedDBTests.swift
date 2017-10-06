import XCTest
@testable import ServiceWorker
import PromiseKit

class IndexedDBTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testIndexedDB() {

        let sw = ServiceWorker.createTestWorker(id: self.name)

        sw.evaluateScript("""
            new Promise((fulfill,reject) => {
                var openRequest = indexedDB.open("testDB",1);
                openRequest.onsuccess = fulfill;
                openRequest.onerror = reject;
            })
        """)
            .then { (jsVal: JSContextPromise) in
                return jsVal.resolve()
            }
            .then { _ -> Promise<Void> in
                return sw.ensureFinished()
            }
            .assertResolves()
    }

    func testIndexedDBPutAndFetch() {

        // Stole this from here: https://gist.githubusercontent.com/BigstickCarpet/a0d6389a5d0e3a24814b/raw/fcc4d80489cbcb78f052b3f2c524a805af9b06dd/IndexedDB101.js

        let sw = ServiceWorker.createTestWorker(id: self.name)

        sw.evaluateScript("""
            new Promise(function(fulfill, reject) {
                // Open (or create) the database
                var open = indexedDB.open("MyDatabase", 1);

                // Create the schema
                open.onupgradeneeded = function() {
                    var db = open.result;
                    var store = db.createObjectStore("MyObjectStore", {keyPath: "id"});
                    var index = store.createIndex("NameIndex", ["name.last", "name.first"]);
                };
                open.onerror = reject;

                open.onsuccess = function() {
                    console.log('opened');
                    // Start a new transaction
                    var db = open.result;
                    var tx = db.transaction("MyObjectStore", "readwrite");
                    var store = tx.objectStore("MyObjectStore");
                    var index = store.index("NameIndex");

                    // Add some data
                    store.put({id: 12345, name: {first: "John", last: "Doe"}, age: 42});
                    store.put({id: 67890, name: {first: "Bob", last: "Smith"}, age: 35});
                    
                    var promises = [];

                    promises.push(new Promise((fulfill,reject) => {
                        var getJohn = store.get(12345);
                        getJohn.onsuccess = function() {
                            console.log("got john")
                            fulfill(getJohn.result.name.first);  // => "John"
                        };
                        getJohn.onerror = reject;
                    }));

                    promises.push(new Promise((fulfill,reject) => {
                        var getBob = index.get(["Smith", "Bob"]);
                        getBob.onsuccess = function() {
                            console.log("got bob")
                            fulfill(getBob.result.name.first);   // => "Bob"
                        };
                        getBob.onerror = reject;
                    }));

                    fulfill(Promise.all(promises)
                    .then(function(data) {
                        db.close();
                        return data;
                    }));
                   
                }
            });
        """)
            .then { (jsVal: JSContextPromise) in
                return jsVal.resolve()
            }
            .then { (arr: [String]) -> Promise<Void> in

                XCTAssertEqual(arr[0], "John")
                XCTAssertEqual(arr[1], "Bob")
                return sw.ensureFinished()
            }
            .assertResolves()
    }
}
