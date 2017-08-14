import { assert } from "chai";

describe("Service Worker Container", () => {
    it("Should register a service worker", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js")
            .then(reg => {
                console.log(reg);
            });
    });
});
