self.addEventListener("message", e => {
    if (e.data.action === "exec") {
        let func = new Function(e.data.js);
        e.waitUntil(
            Promise.resolve()
                .then(() => {
                    // allows us to catch errors
                    return Promise.resolve(func());
                })
                .then(response => {
                    e.ports[0].postMessage({ response });
                })
                .catch(error => {
                    e.ports[0].postMessage({ error: error.message });
                })
        );
    }
});
