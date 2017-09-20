import { apiRequest } from "../util/api-request";
import { eventStream } from "../event-stream";
import { MessagePortAction } from "../responses/api-responses";
import { serializeTransferables } from "./transferrable-converter";

class MessagePortProxy {
    port: MessagePort;
    id: string;

    constructor(port: MessagePort, id: string) {
        this.port = port;
        this.id = id;
        this.port.addEventListener("message", this.receiveMessage.bind(this));
        this.port.start();
    }

    receiveMessage(e: MessageEvent) {
        console.log("! GOT MESSAGE", e);
        apiRequest("/MessagePort/proxyMessage", {
            id: this.id,
            message: e.data
        }).catch(err => {
            console.error("Failed to proxy MessagePort message", err);
        });
    }
}

let currentProxies = new Map<String, MessagePortProxy>();

export function addProxy(port: MessagePort, id: string) {
    currentProxies.set(id, new MessagePortProxy(port, id));
}

eventStream.addEventListener<MessagePortAction>("messageport", e => {
    let existingProxy = currentProxies.get(e.data.id);
    if (!existingProxy) {
        throw new Error(
            `Tried to send ${e.data.type} to MessagePort that does not exist`
        );
    }
    if (e.data.type == "message") {
        existingProxy.port.postMessage(e.data.data);
    } else {
        // is close. Remove from collection, free up for garbage collection.
        console.info(
            "Closing existing MessagePort based on native garbage collection."
        );
        currentProxies.delete(e.data.id);
        existingProxy.port.close();
    }
});
