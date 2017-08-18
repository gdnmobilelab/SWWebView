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

    it.only("Should register with default scope as JS file directory", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js")
            .then(reg => {
                assert.equal(
                    reg.scope,
                    new URL("/fixtures/", window.location.href).href
                );
                console.log(reg.installing);
                // reg.installing!.onstatechange = e =>
                //     console.log(e.target.state);
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

    it("Should fail when loading out of scope", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js", {
                scope: "/no-fixtures/"
            })
            .catch(err => {
                return "Errored!";
            })
            .then(result => {
                assert.equal(result, "Errored!");
            });
    });

    it("Should fail when loading off-domain", () => {
        return navigator.serviceWorker
            .register("https://www.example.com/test-worker.js")
            .catch(err => {
                return "Errored!";
            })
            .then(result => {
                assert.equal(result, "Errored!");
            });
    });
});
