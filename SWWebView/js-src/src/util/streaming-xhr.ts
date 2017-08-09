import EventTarget from "eventtarget";
import { API_REQUEST_METHOD } from "swwebview-settings";

export class StreamingXHR extends EventTarget {
    private xhr: XMLHttpRequest;
    private seenBytes = 0;

    constructor(url: string) {
        super();
        this.xhr = new XMLHttpRequest();
        this.xhr.open(API_REQUEST_METHOD, url);
        this.xhr.onreadystatechange = this.receiveData;
        this.xhr.send();
    }

    receiveData() {
        if (this.xhr.readyState !== 3) {
            return;
        }

        let newData = this.xhr.response.substr(this.seenBytes);
        let [_, event, data] = /(\w+):(.*)/.exec(newData)!;

        let evt = new MessageEvent(event, JSON.parse(data));
        this.dispatchEvent(evt);
    }
}
