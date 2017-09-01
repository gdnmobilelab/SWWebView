self.addEventListener("activate", e => {
    e.waitUntil(self.clients.claim());
});
