import { assert } from "chai";
import { withIframe } from "../util/with-iframe";

describe("Service Worker Container", () => {
    afterEach(() => {
        console.groupCollapsed("Unregister calls");
        return navigator.serviceWorker
            .getRegistrations()
            .then((regs: ServiceWorkerRegistration[]) => {
                console.info(
                    "Unregistering:" + regs.map(r => r.scope).join(", ")
                );
                let mapped = regs.map(r => r.unregister());

                return Promise.all(mapped);
            })
            .then(() => {
                console.groupEnd();
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
                console.log(reg.installing);
                // reg.installing!.onstatechange = e =>
                //     console.log(e.target.state);
            });
    });

    it("Should fire ready promise", function() {
        // have to use iframe as none of the fixture JS files are in this
        // page's scope
        return withIframe("/fixtures/blank.html", ({ navigator }) => {
            navigator.serviceWorker.register("./test-register-worker.js");
            return navigator.serviceWorker.ready.then(reg => {
                return navigator.serviceWorker.getRegistration().then(reg2 => {
                    assert.equal(reg, reg2);
                });
            });
        });
    });

    it.only("Should fire oncontrollerchange promise", function() {
        // have to use iframe as none of the fixture JS files are in this
        // page's scope
        return withIframe("/fixtures/blank.html", ({ navigator }) => {
            return new Promise((fulfill, reject) => {
                navigator.serviceWorker.oncontrollerchange = fulfill;
                navigator.serviceWorker
                    .register("./test-take-control-worker.js")
                    .then(reg => {
                        console.log(reg.active.state);
                    });
            }).then(() => {
                assert.equal(
                    navigator.serviceWorker.controller.state,
                    "activated"
                );
            });
        });
    });

    it("Should unregister", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js")
            .then(reg => {
                return reg.unregister();
            })
            .then(() => {
                return navigator.serviceWorker.getRegistrations();
            })
            .then(regs => {
                assert.equal(regs.length, 0);
                // check registering a new one has no old workers
                return navigator.serviceWorker.register(
                    "/fixtures/test-register-worker.js"
                );
            })
            .then(reg => {
                console.log("reg2", Object.assign({}, reg));
                assert.notEqual(
                    reg.installing,
                    null,
                    "New installing worker should exist"
                );
                assert.equal(reg.waiting, null, "Waiting should be null");
                assert.equal(reg.active, null, "Active should be null");
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
