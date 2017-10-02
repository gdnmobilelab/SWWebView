import { execInWorker } from "../util/exec-in-worker";
import { waitUntilWorkerIsActivated } from "../util/sw-lifecycle";
import { assert } from "chai";
import { unregisterEverything } from "../util/unregister-everything";

describe("Cache", () => {
    afterEach(() => {
        return navigator.serviceWorker
            .getRegistration("/fixtures/")
            .then(reg => {
                return execInWorker(
                    reg.active!,
                    `
                return caches.keys().then(keys => {
                    return Promise.all(keys.map(k => caches.delete(k)));
                });
            `
                );
            })
            .then(() => {
                return unregisterEverything();
            });
    });

    it("should put() requests and responses", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    let request = new Request('/');
                    let response = new Response("hello");
                    
                    return caches.open('test-cache')
                        .then((cache) => {
                            return cache.put(request, response)
                            .then(() => {
                                return cache.match(request);
                            })
                        })
                        .then((response) => {
                            return response.text()
                        })
                    `
                );
            })
            .then(cacheResponse => {
                assert.equal(cacheResponse, "hello");
            });
    });

    it("should use ignoreSearch match option", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    let request = new Request('/test?test=value');
                    let response = new Response("hello");
                    
                    return caches.open('test-cache')
                        .then((cache) => {
                            return cache.put(request, response)
                            .then(() => {

                                let noSearchRequest = new Request('/test')

                                return Promise.all([
                                    cache.match(noSearchRequest),
                                    cache.match(noSearchRequest, {ignoreSearch: true})
                                ]);
                            })
                        })
                        .then((responses) => {
                            return responses.map((response) => response ? true : false)
                        })
                    `
                );
            })
            .then((cacheResponses: boolean[]) => {
                assert.equal(cacheResponses.length, 2);
                assert.equal(cacheResponses[0], false);
                assert.equal(cacheResponses[1], true);
            });
    });

    it("should use ignoreMethod match option", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    let request = new Request('/test');
                    let response = new Response("hello");
                    
                    return caches.open('test-cache')
                        .then((cache) => {
                            return cache.put(request, response)
                            .then(() => {

                                let postRequest = new Request('/test', {
                                    method: "POST"
                                })

                                return Promise.all([
                                    cache.match(postRequest),
                                    cache.match(postRequest, {ignoreMethod: true})
                                ]);
                            })
                        })
                        .then((responses) => {
                            return responses.map((response) => response ? true : false)
                        })
                    `
                );
            })
            .then((cacheResponses: boolean[]) => {
                assert.equal(cacheResponses.length, 2);
                assert.equal(cacheResponses[0], false);
                assert.equal(cacheResponses[1], true);
            });
    });

    it("should use ignoreVary match option", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    let request = new Request('/test', {
                        headers: {
                            'X-Vary-Header':'value1'
                        }
                    });
                    let response = new Response("hello", {
                        headers: {
                            Vary: 'X-Vary-Header'
                        }
                    });
                    
                    return caches.open('test-cache')
                        .then((cache) => {
                            return cache.put(request, response)
                            .then(() => {

                                let variedRequest = new Request('/test', {
                                    headers: {
                                        'X-Vary-Header':'value2'
                                    }
                                })

                                return Promise.all([
                                    cache.match(variedRequest),
                                    cache.match(variedRequest, {ignoreVary: true})
                                ]);
                            })
                        })
                        .then((responses) => {
                            return responses.map((response) => response ? true : false)
                        })
                    `
                );
            })
            .then((cacheResponses: boolean[]) => {
                assert.equal(cacheResponses.length, 2);
                assert.equal(cacheResponses[0], false);
                assert.equal(cacheResponses[1], true);
            });
    });

    it("should match() on caches object and respect cacheName option", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    let request = new Request('/test');
                    let response = new Response("hello");
                    
                    return caches.open('test-cache')
                        .then((cache) => {
                            return cache.put(request, response)
                            .then(() => {
                                return Promise.all([
                                    caches.match(request),
                                    caches.match(request, {cacheName: 'test-cache2'})
                                ]);
                            })
                        })
                        .then((responses) => {
                            return responses.map((response) => response ? true : false)
                        })
                    `
                );
            })
            .then((cacheResponses: boolean[]) => {
                assert.equal(cacheResponses.length, 2);
                assert.equal(cacheResponses[0], true);
                assert.equal(cacheResponses[1], false);
            });
    });

    it("should successfully matchAll()", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    let request = new Request('/test');
                    let request2 = new Request('/test?withsearch');
                    let response = new Response("hello");
                    let response2 = new Response("hello2");
                    
                    return caches.open('test-cache')
                        .then((cache) => {
                            return Promise.all([
                                cache.put(request, response),
                                cache.put(request2, response2)
                            ])
                            .then(() => {
                                return cache.matchAll(request, {ignoreSearch: true})
                            })
                        })
                        .then((responses) => {
                            return Promise.all(responses.map((response) => response.text()))
                        })
                    `
                );
            })
            .then((cacheResponses: string[]) => {
                assert.equal(cacheResponses.length, 2);
                assert.equal(cacheResponses[0], "hello");
                assert.equal(cacheResponses[1], "hello2");
            });
    });

    it("should successfully add()", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    return caches.open('test-cache')
                    .then((cache) => {
                        return cache.add('/fixtures/cache-file.txt')
                        .then(() => {
                            return cache.match('/fixtures/cache-file.txt');
                        })
                    })
                    .then((response) => {
                        return response.text()
                    })
                `
                );
            })
            .then(cacheResponse => {
                assert.equal(cacheResponse, "this is cached content");
            });
    });

    it("should successfully addAll()", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    return caches.open('test-cache')
                    .then((cache) => {
                        return cache.addAll([
                            '/fixtures/cache-file.txt',
                            '/fixtures/cache-file2.txt'
                        ])
                        .then(() => {
                            return Promise.all([
                                cache.match('/fixtures/cache-file.txt'),
                                cache.match('/fixtures/cache-file2.txt')
                            ])
                        })
                    })
                    .then((responses) => {
                        return Promise.all(responses.map((r) => r.text()))
                    })
                `
                );
            })
            .then((cacheResponses: string[]) => {
                assert.equal(cacheResponses[0], "this is cached content");
                assert.equal(
                    cacheResponses[1],
                    "this is the second cached file"
                );
            });
    });

    it("should successfully return keys()", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    return caches.open('test-cache')
                    .then((cache) => {
                        return cache.addAll([
                            '/fixtures/cache-file.txt',
                            '/fixtures/cache-file2.txt'
                        ])
                        .then(() => {
                            return cache.keys()
                        })
                    })
                    .then((keys) => {
                        return keys.map((r) => r.url)
                    })
                `
                );
            })
            .then((cacheResponses: string[]) => {
                let urlOne = new URL(
                    "/fixtures/cache-file.txt",
                    window.location.href
                );
                let urlTwo = new URL(
                    "/fixtures/cache-file2.txt",
                    window.location.href
                );

                assert.equal(cacheResponses[0], urlOne.href);
                assert.equal(cacheResponses[1], urlTwo.href);
            });
    });

    it("should successfully delete()", () => {
        return navigator.serviceWorker
            .register("/fixtures/exec-worker.js")
            .then(reg => {
                return waitUntilWorkerIsActivated(reg.installing!);
            })
            .then(worker => {
                return execInWorker(
                    worker,
                    `
                    return caches.open('test-cache')
                    .then((cache) => {
                        return cache.add('/fixtures/cache-file.txt')
                        .then(() => {
                            return cache.delete('/fixtures/cache-file.txt')
                        })
                        .then((didDelete) => {
                            return cache.keys()
                            .then((keys) => {
                                return [keys.length, didDelete]
                            })
                        })
                    })
                    
                `
                );
            })
            .then((responses: any[]) => {
                assert.equal(responses[0], 0);
                assert.equal(responses[1], true);
            });
    });
});
