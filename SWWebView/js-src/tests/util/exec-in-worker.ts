export function execInWorker(worker: ServiceWorker, js: string) {
    return new Promise((fulfill, reject) => {
        let channel = new MessageChannel();

        worker.postMessage(
            {
                action: "exec",
                js: js,
                port: channel.port1
            },
            [channel.port1]
        );

        channel.port2.onmessage = function(e: MessageEvent) {
            if (e.data.error) {
                reject(new Error(e.data.error));
            }
            fulfill(e.data.response);
        };
    });
}
