import { assert } from "chai";

describe("Service Worker Container", () => {
    afterEach(() => {
        return navigator.serviceWorker
            .getRegistrations()
            .then((regs: ServiceWorkerRegistration[]) => {
                let mapped = regs.map(r => r.unregister());

                return Promise.all(mapped);
            });
    });

    it("Should register with default scope as JS file directory", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js")
            .then(reg => {
                assert.equal(
                    reg.scope,
                    new URL("/fixtures/", window.location.href).href
                );
            });
    });

    it("Should register with specified scope", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js", {
                scope: "/fixtures/a-test-scope"
            })
            .then(reg => {
                assert.equal(
                    reg.scope,
                    new URL("/fixtures/a-test-scope", window.location.href).href
                );
            });
    });

    it("Should fail when loading off-domain", () => {
        return navigator.serviceWorker
            .register("https://www.example.com/test-worker.js")
            .catch(err => {
                console.log(err);
                return "Errored!";
            })
            .then(result => {
                assert.equal(result, "Errored!");
            });
    });
});
