self.addEventListener("message", e => {
    e.ports[0].postMessage("response");
    e.ports[0].onmessage = function() {
        e.ports[0].postMessage("response2");
    };
});
