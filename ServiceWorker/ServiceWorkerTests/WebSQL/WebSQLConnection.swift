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
            //            .then { promiseResult in
            //                XCTAssertEqual(promiseResult?.toBool(), true)
            //            }
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
                            
                            tx.executeSql("SELECT 'test' as textval", [], function(results) {
                                fulfill(results.rows[0].textval)
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
            .then { promiseResult in
                XCTAssertEqual(promiseResult?.value.toString(), "test")
            }
            .assertResolves()
    }
}
