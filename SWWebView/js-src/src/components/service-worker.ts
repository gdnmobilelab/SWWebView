import EventEmitter from "tiny-emitter";
import { ServiceWorkerAPIResponse } from "../responses/api-responses";

const existingWorkers: ServiceWorkerImplementation[] = [];

export class ServiceWorkerImplementation extends EventEmitter
    implements ServiceWorker {
    id: string;
    scriptURL: string;
    state: ServiceWorkerState;
    onstatechange: () => void;
    onerror: (Error) => void;

    constructor(opts: ServiceWorkerAPIResponse) {
        super();
        this.scriptURL = opts.scriptURL;
        this.id = opts.id;
        this.state = opts.installState;
    }

    postMessage() {}

    static getOrCreate(opts: ServiceWorkerAPIResponse) {
        let existing = existingWorkers.find(w => w.id === opts.id);
        if (existing) {
            return existing;
        } else {
            let newWorker = new ServiceWorkerImplementation(opts);
            existingWorkers.push(newWorker);
            return newWorker;
        }
    }
}
