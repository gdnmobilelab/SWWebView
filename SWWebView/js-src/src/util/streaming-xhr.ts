import EventEmitter from "tiny-emitter";
import { API_REQUEST_METHOD } from "swwebview-settings";

interface CustomMessageEvent<T> extends MessageEvent {
    data: T;
}

export class StreamingXHR extends EventEmitter {
    private xhr: XMLHttpRequest;
    private seenBytes = 0;
    private isOpen = false;
    private url: string;

    constructor(url: string) {
        super();
        this.url = url;
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
        // try {
        if (this.xhr.readyState !== 3) {
            return;
        }

        // This means the responseText keeps growing and growing. Perhaps
        // we should look into cutting this off and re-establishing a new
        // link if it gets too big.
        let newData = this.xhr.responseText.substr(this.seenBytes);

        this.seenBytes = this.xhr.responseText.length;
        let [_, event, data] = /([\w\-]+):(.*)/.exec(newData)!;
        let evt = new MessageEvent(event, {
            data: JSON.parse(data)
        });
        // console.info("EVENT:", event, evt.data);
        this.dispatchEvent(evt);
        // } catch (err) {
        //     console.error(err);
        //     let errEvt = new ErrorEvent("error", {
        //         error: err
        //     });
        //     this.dispatchEvent(errEvt);
        // }
    }

    close() {
        this.xhr.abort();
    }
}
