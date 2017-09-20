import EventEmitter from "tiny-emitter";
import { API_REQUEST_METHOD } from "swwebview-settings";

interface CustomMessageEvent<T> extends MessageEvent {
    data: T;
}

export class StreamingXHR extends EventEmitter {
    private xhr: XMLHttpRequest;
    private eventSource: EventSource;
    private seenBytes = 0;
    isOpen = false;
    private url: string;

    // We allow subscribing before we've created the EventSource
    // itself, so we need to keep track of what we have and have
    // not subscribed to.
    private subscribedEvents: string[] = [];

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
        this.receiveNewEvent = this.receiveNewEvent.bind(this);
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

        this.eventSource = new EventSource(this.url);

        this.subscribedEvents.forEach(type => {
            // Add listeners for each of the types we have already added
            this.eventSource.addEventListener(type, this.receiveNewEvent);
        });

        (this.eventSource as any).onopen = () => {
            if (this.readyFulfill) {
                this.readyFulfill();
                this.readyFulfill = undefined;
            }
        };

        (this.eventSource as any).onclose = () => {
            this.isOpen = false;
            this.resetReadyPromise();
        };

        // this.xhr = new XMLHttpRequest();

        // this.xhr.open(API_REQUEST_METHOD, this.url);
        // this.xhr.onreadystatechange = this.receiveData.bind(this);
        // this.xhr.send();
    }

    addEventListener<T>(
        type: string,
        func: (e: CustomMessageEvent<T>) => void
    ) {
        super.addEventListener(type, func);
        if (this.subscribedEvents.indexOf(type) === -1) {
            if (this.eventSource) {
                // If our event source is already open then we need to
                // add a new event listener immediately.
                this.eventSource.addEventListener(type, this.receiveNewEvent);
            }
            this.subscribedEvents.push(type);
        }
        // this.eventSource.addEventListener(type, func);
    }

    receiveNewEvent(e: MessageEvent) {
        if (e.isTrusted === false) {
            return;
        }

        let jsonMsgEvent = new MessageEvent(
            e.type,
            Object.assign({}, e, { data: JSON.parse(e.data) })
        );

        this.dispatchEvent(jsonMsgEvent);
    }

    // receiveData() {
    //     if (this.xhr.readyState === 4) {
    //         this.isOpen = false;
    //         this.resetReadyPromise();

    //         setTimeout(() => {
    //             // This doesn't fire if page is unloading. So re-establish
    //             // connection here?
    //             console.error("Streaming task has stopped");
    //         }, 1);
    //     }

    //     if (this.xhr.readyState !== 3) {
    //         return;
    //     }

    //     if (this.readyFulfill) {
    //         this.readyFulfill();
    //         this.readyFulfill = undefined;
    //     }

    //     // This means the responseText keeps growing and growing. Perhaps
    //     // we should look into cutting this off and re-establishing a new
    //     // link if it gets too big.
    //     let newData = this.xhr.responseText.substr(this.seenBytes);
    //     this.seenBytes = this.xhr.responseText.length;

    //     let events = newData.split("\n");

    //     events.filter(s => s !== "").forEach(dataSlice => {
    //         let [_, event, data] = /([\w\-]+):(.*)/.exec(dataSlice)!;
    //         let parsedData;
    //         try {
    //             parsedData = JSON.parse(data);
    //         } catch (err) {
    //             throw new Error(
    //                 "Could not parse: " + dataSlice + err.toString()
    //             );
    //         }

    //         let evt = new MessageEvent(event, {
    //             data: parsedData
    //         });
    //         this.dispatchEvent(evt);
    //     });
    // }

    close() {
        (this.eventSource as any).close();
        // this.xhr.abort();
    }
}
