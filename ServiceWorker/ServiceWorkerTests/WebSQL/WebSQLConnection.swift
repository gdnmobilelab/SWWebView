import XCTest
@testable import ServiceWorker
import PromiseKit
import SQLite3
import JavaScriptCore

class WebSQLConnectionTests: XCTestCase {

    static let webSQLTestPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("websql", isDirectory: true)

    override func setUp() {
        super.setUp()

        do {

            if FileManager.default.fileExists(atPath: WebSQLConnectionTests.webSQLTestPath.path) {
                try FileManager.default.removeItem(atPath: WebSQLConnectionTests.webSQLTestPath.path)
            }
            try FileManager.default.createDirectory(at: WebSQLConnectionTests.webSQLTestPath, withIntermediateDirectories: true, attributes: nil)

        } catch {
            XCTFail("\(error)")
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    class WebSQLTestDelegate: NSObject, ServiceWorkerDelegate {
        func serviceWorkerGetDomainStoragePath(_ worker: ServiceWorker) throws -> URL {
            return webSQLTestPath.appendingPathComponent(worker.url.host!, isDirectory: true)
        }

        func serviceWorker(_: ServiceWorker, importScript _: URL, _ callback: @escaping (Error?, String?) -> Void) {
            callback(ErrorMessage("not implemented"), nil)
        }

        func serviceWorkerGetScriptContent(_: ServiceWorker) throws -> String {
            return ""
        }

        func getCoreDatabaseURL() -> URL {
            return webSQLTestPath.appendingPathComponent("core.db")
        }

        static let instance = WebSQLTestDelegate()
    }

    func injectOpenDBIntoWorker(_ sw: ServiceWorker) -> Promise<Void> {

        sw.delegate = WebSQLTestDelegate.instance

        return sw.getExecutionEnvironment()
            .then { exec in

                let openDatabaseFunction: @convention(block) (String, String, String, Int, JSValue?) -> WebSQLDatabase? = { [unowned exec] name, _, _, _, _ in
                    try! exec.openWebSQLDatabase(name: name)
                }

                return sw.withJSContext { context in
                    GlobalVariableProvider.add(variable: openDatabaseFunction, to: context, withName: "openDatabase")
                }
            }
    }

    func testOpeningDatabase() {

        let sw = ServiceWorker.createTestWorker(id: name)

        injectOpenDBIntoWorker(sw)
            .then {
                return sw.evaluateScript("""
                var db = openDatabase('test', 1, 'pretty name', 1024);
                var result = typeof db.transaction !== 'undefined';

                result;
                """)
            }
            .then { (jsResult: Bool?) -> Promise<Void> in
                XCTAssertEqual(jsResult, true)
                return sw.ensureFinished()
            }
            .assertResolves()
    }

    func testTransactionCallback() {

        let sw = ServiceWorker.createTestWorker(id: name)

        injectOpenDBIntoWorker(sw)
            .then {
                return sw.evaluateScript("""
                   
                     new Promise(function(fulfill, reject) {
                        var db = openDatabase('test', 1, 'pretty name', 1024);
                        var callbackCalled = false;

                        db.transaction(function(tx) {
                            callbackCalled = true;
                        }, function(err) {
                            reject(err)
                        }, function() {
                            delete db;
                            fulfill(callbackCalled)
                        })

                    })
                """)
            }
            .then { (jsResult: JSContextPromise) in
                return jsResult.resolve()
            }
            .then {
                return sw.ensureFinished()
            }
            .assertResolves()
    }

    func testResultSetSelect() {

        let sw = ServiceWorker.createTestWorker(id: name)

        injectOpenDBIntoWorker(sw)
            .then {
                return sw.evaluateScript("""
                    var db = openDatabase('test', 1, 'pretty name', 1024);
                    new Promise(function(fulfill, reject) {

                       db.transaction(function(tx) {
                            
                            tx.executeSql("SELECT 'test' as textval", [], function(tx,results) {
                                fulfill(results.rows.item(0).textval)
                            }, function() {
                               
                            })
                        }, function() {
                        })

                    })
                """)
            }
            .then { (jsResult: JSContextPromise) in
                return jsResult.resolve()
            }
            .then { (promiseResult: String) -> Promise<Void> in
                XCTAssertEqual(promiseResult, "test")
                return sw.ensureFinished()
            }
            .assertResolves()
    }

    func testMultipleQueries() {

        let sw = ServiceWorker.createTestWorker(id: name)

        injectOpenDBIntoWorker(sw)
            .then {
                return sw.evaluateScript("""

                    var assert = {
                        equal: function (a,b) {
                            if (a != b) throw new Error(a + " does not match " + b);
                        }
                    }

                    var db = openDatabase('testdb', '1.0', 'yolo', 100000);
                    
                    new Promise(function (resolve, reject) {
                      db.transaction(function (txn) {
                        txn.executeSql('SELECT 1 + 1', [], function (txn, result) {
                          resolve(result);
                        }, function (txn, err) {
                          reject(err);
                        });
                      });
                    })
                    .then(function (res) {
                      assert.equal(res.rowsAffected, 0);
                      assert.equal(res.rows.length, 1);
                      assert.equal(res.rows.item(0)['1 + 1'], 2);

                      return new Promise(function (resolve, reject) {
                        db.transaction(function (txn) {
                          txn.executeSql('SELECT 2 + 1', [], function (txn, result) {
                            resolve(result);
                          }, function (txn, err) {
                            reject(err);
                          });
                        });
                      });
                    }).then(function (res) {
                      assert.equal(res.rowsAffected, 0);
                      assert.equal(res.rows.length, 1);
                      assert.equal(res.rows.item(0)['2 + 1'], 3);
                    });
                """)
            }
            .then { (jsResult: JSContextPromise) -> Promise<Void> in
                return jsResult.resolve()
            }
            .then {
                return sw.ensureFinished()
            }
            .assertResolves()
    }

    func testCallsCompleteCallback() {

        let sw = ServiceWorker.createTestWorker(id: name)

        injectOpenDBIntoWorker(sw)
            .then {
                return sw.evaluateScript("""

                        var assert = {
                        equal: function (a,b) {
                        if (a != b) throw new Error(a + " does not match " + b);
                        }
                        }
                
                
                
                        var db = openDatabase(':memory:', '1.0', 'yolo', 100000);

                        var called = 0;

                        new Promise(function (resolve, reject) {
                            db.transaction(function () {
                            }, reject, resolve);
                        }).then(function () {
                            assert.equal(called, 0);
                        });
                """)
            }.then { (jsResult: JSContextPromise) in
                return jsResult.resolve()
            }
            .then {
                return sw.ensureFinished()
            }
            .assertResolves()
    }
}
