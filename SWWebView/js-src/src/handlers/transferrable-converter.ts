export function serializeTransferables(message: any, transferables: any[]) {
    // Messages can pass transferables, but those transferables can also exist
    // within the message. We need to replace any instances of those transferables
    // with serializable objects.

    if (transferables.indexOf(message) > -1) {
        return {
            __transferable: {
                index: transferables.indexOf(message)
            }
        };
    } else if (message instanceof Array) {
        return message.map(m => serializeTransferables(m, transferables));
    } else if (
        typeof message == "number" ||
        typeof message == "string" ||
        typeof message == "boolean"
    ) {
        return message;
    } else {
        let obj = {};
        Object.keys(message).forEach(key => {
            obj[key] = serializeTransferables(message[key], transferables);
        });
        return obj;
    }
}
