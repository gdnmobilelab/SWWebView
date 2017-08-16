import { assert } from "chai";

describe("Service Worker Container", () => {
    afterEach(() => {
        return navigator.serviceWorker
            .getRegistrations()
            .then((regs: ServiceWorkerRegistration[]) => {
                let mapped = regs.map(r => r.unregister());
                console.log(regs);
                console.log("UNREGISTER");
                return Promise.all(mapped);
            });
    });

    it.only(
        "Should register with default scope as JS file directory",
        function() {
            this.timeout(10000);
            console.log("RUN");
            return navigator.serviceWorker
                .register("/fixtures/test-register-worker.js")
                .then(reg => {
                    assert.equal(
                        reg.scope,
                        new URL("/fixtures/", window.location.href).href
                    );
                    console.log("NOW DO GET REG");
                    return navigator.serviceWorker
                        .getRegistration("/fixtures/")
                        .then(reg2 => {
                            console.log("regs", reg, reg2);
                            assert.equal(reg, reg2);
                        });
                });
        }
    );

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
