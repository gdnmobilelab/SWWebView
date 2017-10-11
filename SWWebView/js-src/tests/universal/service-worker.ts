import { assert } from "chai";
import { withIframe } from "../util/with-iframe";
import { waitUntilWorkerIsActivated } from "../util/sw-lifecycle";
import { unregisterEverything } from "../util/unregister-everything";
import { execInWorker } from "../util/exec-in-worker";

describe("Service Worker", () => {
    afterEach(() => {
        return unregisterEverything();
    });

    it("Should post a message", done => {
        let channel = new MessageChannel();

        let numberOfMessages = 0;

        channel.port2.onmessage = function(e) {
            console.timeEnd("Round-trip message");
            numberOfMessages++;
            console.log(e);

            e.ports[0].onmessage = () => {
                console.timeEnd("Second round-trip message");
                done();
            };
            console.time("Second round-trip message");
            e.ports[0].postMessage("reply");
        };

        navigator.serviceWorker
            .register("/fixtures/test-message-reply-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                console.time("Round-trip message");
                worker.postMessage({ hello: "there", port: channel.port1 }, [
                    channel.port1
                ]);
            });
    });

    it("Should import a script successfully", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                self.testValue = "unset";
                importScripts("./script-to-import.js");
                return self.testValue;
                `
                );
            })
            .then(returnValue => {
                assert.equal(returnValue, "set");
            });
    });

    it("Should import multiple scripts successfully", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                self.testValue = "unset";
                importScripts("./script-to-import.js","./script-to-import2.js");
                return self.testValue;
                `
                );
            })
            .then(returnValue => {
                assert.equal(returnValue, "set again");
            });
    });

    it("Should send fetch events to worker, and worker should respond", () => {
        return withIframe("/fixtures/blank.html", ({ window, navigator }) => {
            navigator.serviceWorker.register("./test-response-worker.js");

            return new Promise(fulfill => {
                navigator.serviceWorker.oncontrollerchange = fulfill;
            })
                .then(reg => {
                    return window.fetch("testfile?test=hello");
                })
                .then(res => {
                    assert.equal(res.status, 200);
                    assert.equal(
                        res.headers.get("content-type"),
                        "application/json"
                    );
                    return res.json();
                })
                .then(json => {
                    assert.equal(json.success, true);
                    assert.equal(json.queryValue, "hello");
                });
        });
    });

    // it.only("Should successfully open an indexedDB database", function() {
    //     this.timeout(50000);
    //     return navigator.serviceWorker
    //         .register("/fixtures/exec-worker.js")
    //         .then(reg => {
    //             return waitUntilWorkerIsActivated(reg.installing!);
    //         })
    //         .then(worker => {
    //             return execInWorker(
    //                 worker,
    //                 `
    //         return new Promise((fulfill,reject) => {
    //             try {
    //                 console.log("do open")
    //                 var openRequest = indexedDB.open("testDB",1);
    //                 console.log("request successful")
    //                 openRequest.onsuccess = () => {
    //                     // fulfill(true)
    //                 };
    //                 openRequest.onerror = (err) => {
    //                     reject(err)
    //                 };
    //             } catch (err) {
    //                 console.log("error caught");
    //                 reject(err)
    //             }
    //         })
    //         `
    //             );
    //         })
    //         .then(returnValue => {
    //             assert.equal(returnValue, true);
    //         });
    // });
});
