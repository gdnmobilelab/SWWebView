export function withIframe(
    src: string = "/fixtures/blank.html",
    cb: (Window) => Promise<void> | void
): Promise<void> {
    return new Promise((fulfill, reject) => {
        let iframe = document.createElement("iframe");

        iframe.onload = () => {
            fulfill(
                Promise.resolve(cb(iframe.contentWindow))
                    .then(() => {
                        return iframe.contentWindow.navigator.serviceWorker.getRegistrations();
                    })
                    .then((regs: ServiceWorkerRegistration[]) => {
                        let mapped = regs.map(r => r.unregister());
                        return Promise.all(mapped);
                    })
                    .then(() => {
                        return new Promise<void>((fulfill, reject) => {
                            setTimeout(() => {
                                // No idea why this has to be in a timeout, but the promise stops
                                // if it isn't.
                                document.body.removeChild(iframe);
                                // setTimeout(() => {
                                fulfill();
                                // }, 10);
                            }, 1);
                        });
                    })
            );
        };

        iframe.src = src;
        iframe.style.display = "none";
        document.body.appendChild(iframe);
    });
}
