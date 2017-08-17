import EventEmitter from "tiny-emitter";
import { API_REQUEST_METHOD } from "swwebview-settings";

export class StreamingXHR extends EventEmitter {
    private xhr: XMLHttpRequest;
    private seenBytes = 0;

    constructor(url: string) {
        super();
        this.xhr = new XMLHttpRequest();
        this.xhr.open(API_REQUEST_METHOD, url);
        this.xhr.onreadystatechange = this.receiveData.bind(this);
        this.xhr.send();
    }

    receiveData() {
        try {
            if (this.xhr.readyState !== 3) {
                return;
            }

            // This means the responseText keeps growing and growing. Perhaps
            // we should look into cutting this off and re-establishing a new
            // link if it gets too big.
            let newData = this.xhr.responseText.substr(this.seenBytes);
            console.log("new event: ", newData);

            this.seenBytes = this.xhr.responseText.length;
            let [_, event, data] = /([\w\-]+):(.*)/.exec(newData)!;

            let evt = new MessageEvent(event, {
                data: JSON.parse(data)
            });
            this.dispatchEvent(evt);
        } catch (err) {
            let errEvt = new ErrorEvent("error", {
                error: err
            });
            this.dispatchEvent(errEvt);
        }
    }

    close() {
        this.xhr.abort();
    }
}
