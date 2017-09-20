export function unregisterEverything() {
    console.groupCollapsed("Unregister calls");
    return navigator.serviceWorker
        .getRegistrations()
        .then((regs: ServiceWorkerRegistration[]) => {
            console.info("Unregistering:" + regs.map(r => r.scope).join(", "));
            let mapped = regs.map(r => r.unregister());

            return Promise.all(mapped);
        })
        .then(() => {
            console.groupEnd();
        });
}
