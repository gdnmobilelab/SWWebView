import { assert } from "chai";
import { withIframe } from "../util/with-iframe";
import { waitUntilWorkerIsActivated } from "../util/sw-lifecycle";

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

    it("Should be controller on a newly created client", function() {
        return withIframe("/fixtures/blank.html", parentWindow => {
            parentWindow.navigator.serviceWorker.register(
                "./test-register-worker.js"
            );
            return parentWindow.navigator.serviceWorker.ready
                .then(reg => {
                    if (reg.active.state === "activated") {
                        return;
                    }
                    return new Promise((fulfill, reject) => {
                        reg.active.onstatechange = () => {
                            reg.active.onstatechange = null;
                            if (reg.active.state == "activated") {
                                fulfill();
                            }
                        };
                    });
                })
                .then(() => {
                    // we now have a fully installed worker.
                    return withIframe(
                        "/fixtures/blank.html?page2",
                        childWindow => {
                            // shouldn't be necessary, but it is
                            return childWindow.navigator.serviceWorker.ready.then(
                                () => {
                                    let regURL = new URL(
                                        "./test-register-worker.js",
                                        childWindow.location.href
                                    );

                                    assert.equal(
                                        childWindow.navigator.serviceWorker
                                            .controller.scriptURL,
                                        regURL.href
                                    );

                                    assert.notExists(
                                        parentWindow.navigator.serviceWorker
                                            .controller
                                    );
                                }
                            );
                        }
                    );
                });
        });
    });

    it("Should fire oncontrollerchange promise", function() {
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
            })
                .then(() => {
                    assert.equal(
                        navigator.serviceWorker.controller.state,
                        "activating"
                    );
                    return navigator.serviceWorker.ready;
                })
                .then((reg: ServiceWorkerRegistration) => {
                    assert.equal(
                        navigator.serviceWorker.controller,
                        reg.active
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
                assert.notExists(navigator.serviceWorker.controller);
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

    it("Should not automatically claim a registrant that isn't in scope", () => {
        return navigator.serviceWorker
            .register("/fixtures/test-register-worker.js")
            .then(result => {
                return waitUntilWorkerIsActivated(result.installing!);
            })
            .then(() => {
                assert.notExists(navigator.serviceWorker.controller);
            });
    });

    it("Should take over a less specific scope", function() {
        return withIframe("/fixtures/subscope/blank.html", parentFrame => {
            return parentFrame.navigator.serviceWorker
                .register("/fixtures/test-register-worker.js", {
                    scope: "/fixtures/"
                })
                .then(reg => {
                    return waitUntilWorkerIsActivated(reg.installing);
                })
                .then(() => {
                    return parentFrame.navigator.serviceWorker.register(
                        "/fixtures/test-take-control-worker.js",
                        {
                            scope: "/fixtures/subscope/"
                        }
                    );
                })
                .then(reg => waitUntilWorkerIsActivated(reg.installing))
                .then(() => {
                    assert.equal(
                        parentFrame.navigator.serviceWorker.controller
                            .scriptURL,
                        new URL(
                            "/fixtures/test-take-control-worker.js",
                            window.location.href
                        ).href
                    );
                });
        });
    });

    it("Should not take over a more specific scope", function() {
        return withIframe("/fixtures/subscope/blank.html", ({ navigator }) => {
            return navigator.serviceWorker
                .register("/fixtures/test-take-control-worker.js?subscope", {
                    scope: "/fixtures/subscope/"
                })
                .then(reg => {
                    return waitUntilWorkerIsActivated(reg.installing);
                })
                .then(worker => {
                    assert.exists(navigator.serviceWorker.controller);
                    return navigator.serviceWorker.register(
                        "/fixtures/test-take-control-worker.js?notsubscope",
                        {
                            scope: "/fixtures/"
                        }
                    );
                })
                .then(reg => {
                    return waitUntilWorkerIsActivated(reg.installing);
                })
                .then(() => {
                    assert.equal(
                        navigator.serviceWorker.controller.scriptURL,
                        new URL(
                            "/fixtures/test-take-control-worker.js?subscope",
                            window.location.href
                        ).href
                    );
                });
        });
    });
});
