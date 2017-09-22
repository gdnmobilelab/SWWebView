function sendReply(e) {
    e.target.postMessage("response2");
    e.target.onmessage = undefined;
}

self.addEventListener("message", e => {
    let newChannel = new MessageChannel();
    newChannel.port2.onmessage = sendReply;
    e.ports[0].postMessage("response", [newChannel.port1]);
});
