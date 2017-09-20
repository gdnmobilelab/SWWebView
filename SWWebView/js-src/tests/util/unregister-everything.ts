export function unregisterEverything() {
    return navigator.serviceWorker
        .getRegistrations()
        .then((regs: ServiceWorkerRegistration[]) => {
            console.groupCollapsed("Unregister calls");
            console.info("Unregistering:" + regs.map(r => r.scope).join(", "));
            let mapped = regs.map(r => r.unregister());

            return Promise.all(mapped);
        })
        .then(() => {
            console.groupEnd();
        });
}
