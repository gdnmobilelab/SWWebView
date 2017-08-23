import EventEmitter from "tiny-emitter";
import { API_REQUEST_METHOD } from "swwebview-settings";

interface CustomMessageEvent<T> extends MessageEvent {
    data: T;
}

export class StreamingXHR extends EventEmitter {
    private xhr: XMLHttpRequest;
    private seenBytes = 0;
    isOpen = false;
    private url: string;

    get ready() {
        if (this.isOpen === false) {
            // We try to lazy-load this stream if at all possible - that way
            // we don't have any overhead if a page doesn't use any of the
            // SW APIs.
            this.open();
        }
        return this.readyPromise;
    }

    private readyPromise: Promise<void>;
    private readyFulfill?: () => void;

    constructor(url: string) {
        super();
        this.url = url;
        this.resetReadyPromise();
    }

    resetReadyPromise() {
        this.readyPromise = new Promise(fulfill => {
            this.readyFulfill = fulfill;
        });
    }

    open() {
        if (this.isOpen === true) {
            throw new Error("Already open");
        }

        this.isOpen = true;
        this.xhr = new XMLHttpRequest();

        this.xhr.open(API_REQUEST_METHOD, this.url);
        this.xhr.onreadystatechange = this.receiveData.bind(this);
        this.xhr.send();
    }

    addEventListener<T>(
        type: string,
        func: (e: CustomMessageEvent<T>) => void
    ) {
        super.addEventListener(type, func);
    }

    receiveData() {
        if (this.xhr.readyState === 4) {
            this.isOpen = false;
            this.resetReadyPromise();

            setTimeout(() => {
                // This doesn't fire if page is unloading. So re-establish
                // connection here?
                console.error("Streaming task has stopped");
            }, 1);
        }

        if (this.xhr.readyState !== 3) {
            return;
        }

        if (this.readyFulfill) {
            this.readyFulfill();
            this.readyFulfill = undefined;
        }

        // This means the responseText keeps growing and growing. Perhaps
        // we should look into cutting this off and re-establishing a new
        // link if it gets too big.
        let newData = this.xhr.responseText.substr(this.seenBytes);
        this.seenBytes = this.xhr.responseText.length;

        let events = newData.split("\n");

        events.filter(s => s !== "").forEach(dataSlice => {
            let [_, event, data] = /([\w\-]+):(.*)/.exec(dataSlice)!;
            let parsedData;
            try {
                parsedData = JSON.parse(data);
            } catch (err) {
                throw new Error(
                    "Could not parse: " + dataSlice + err.toString()
                );
            }

            let evt = new MessageEvent(event, {
                data: parsedData
            });
            this.dispatchEvent(evt);
        });
    }

    close() {
        this.xhr.abort();
    }
}
