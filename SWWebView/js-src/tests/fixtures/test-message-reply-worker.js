self.addEventListener("message", e => {
    e.ports[0].postMessage("response");
});
