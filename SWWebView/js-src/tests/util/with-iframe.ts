export function withIframe(
    src: string = "/fixtures/blank.html",
    cb: (Window) => Promise<void>
): Promise<void> {
    return new Promise((fulfill, reject) => {
        let iframe = document.createElement("iframe");

        iframe.onload = () => {
            fulfill(
                cb(iframe.contentWindow)
                    .then(errorOrNothing => {
                        return iframe.contentWindow.navigator.serviceWorker.getRegistrations();
                    })
                    .then((regs: ServiceWorkerRegistration[]) => {
                        let mapped = regs.map(r => r.unregister());
                        return Promise.all(mapped);
                    })
                    .then(() => {
                        setTimeout(() => {
                            // No idea why this has to be in a timeout, but the promise stops
                            // if it isn't.
                            document.body.removeChild(iframe);
                        }, 1);
                    })
            );
        };

        iframe.src = src;
        iframe.style.display = "none";
        document.body.appendChild(iframe);
    });
}
