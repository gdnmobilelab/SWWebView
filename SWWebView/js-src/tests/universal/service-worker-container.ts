import { assert } from "chai";

describe("Service Worker Container", () => {
    afterEach(() => {
        return navigator.serviceWorker
            .getRegistration()
            .then((reg: ServiceWorkerRegistration) => {
                reg.unregister();
            });
    });

    it("Should register a service worker", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js")
            .then(reg => {
                console.log(reg);
            });
    });
});
