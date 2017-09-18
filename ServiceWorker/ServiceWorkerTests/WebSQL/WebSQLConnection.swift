//
//  WebSQLConnection.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 04/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
@testable import ServiceWorker
import PromiseKit
import SQLite3

class WebSQLConnectionTests: XCTestCase {

    let webSQLTestPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("websql", isDirectory: true)

    override func setUp() {
        super.setUp()

        ServiceWorkerTestDelegate.storageURL = webSQLTestPath

        do {

            if FileManager.default.fileExists(atPath: self.webSQLTestPath.path) {
                try FileManager.default.removeItem(atPath: self.webSQLTestPath.path)
            }
            try FileManager.default.createDirectory(at: self.webSQLTestPath, withIntermediateDirectories: true, attributes: nil)

        } catch {
            XCTFail("\(error)")
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func injectOpenDBIntoWorker(_ sw: ServiceWorker) -> Promise<Void> {

        return sw.getExecutionEnvironment()
            .then { exec in

                exec.withJSContext { context in
                    GlobalVariableProvider.add(variable: exec.globalScope.openDatabaseFunction!, to: context, withName: "openDatabase")
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
            .then { jsResult -> Promise<Void> in
                XCTAssertEqual(jsResult?.toBool(), true)
                return Promise { fulfill, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        fulfill(())
                    })
                }
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
            .then { jsResult in
                return JSPromise.fromJSValue(jsResult!)
            }
            .then { _ in
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
            .then { jsResult in
                return JSPromise.fromJSValue(jsResult!)
            }
            .then { promiseResult -> Promise<Void> in
                XCTAssertEqual(promiseResult?.value.toString(), "test")
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
            .then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }
            .then { _ in
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
            }.then { jsVal in
                return JSPromise.fromJSValue(jsVal!)
            }
            .then { _ in
                return sw.ensureFinished()
            }
            .assertResolves()
    }
}
