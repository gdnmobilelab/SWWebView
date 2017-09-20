import { assert } from "chai";
import { withIframe } from "../util/with-iframe";
import { waitUntilWorkerIsActivated } from "../util/sw-lifecycle";
import { unregisterEverything } from "../util/unregister-everything";

describe("Service Worker", () => {
    afterEach(() => {
        return unregisterEverything();
    });

    it.only("Should post a message", done => {
        let channel = new MessageChannel();

        channel.port2.onmessage = function() {
            console.timeEnd("Round-trip message");
            done();
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
});
