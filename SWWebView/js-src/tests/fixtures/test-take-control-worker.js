self.addEventListener("activate", () => {
    self.clients.claim();
});
