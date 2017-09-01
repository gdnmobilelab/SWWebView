export function waitUntilWorkerIsActivated(worker: ServiceWorker) {
    return new Promise((fulfill, reject) => {
        let listener = function(e) {
            if (worker.state !== "activated") return;
            worker.removeEventListener("statechange", listener);
            fulfill(worker);
        };
        worker.addEventListener("statechange", listener);
    });
}
