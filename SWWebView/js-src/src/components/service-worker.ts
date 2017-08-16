import EventEmitter from "tiny-emitter";
import { ServiceWorkerAPIResponse } from "../responses/api-responses";

const existingWorkers: ServiceWorkerImplementation[] = [];

export class ServiceWorkerImplementation extends EventEmitter
    implements ServiceWorker {
    onstatechange: (Event) => void;
    onerror: (Error) => void;
    scriptURL: string;
    state: ServiceWorkerState;
    id: string;

    postMessage() {}

    constructor(opts: ServiceWorkerAPIResponse) {
        super();
        this.scriptURL = opts.url;
        this.state = opts.state;
        this.id = opts.id;
    }

    static getOrCreate(opts: ServiceWorkerAPIResponse) {
        let worker = existingWorkers.find(worker => worker.id == opts.id);
        if (!worker) {
            worker = new ServiceWorkerImplementation(opts);
            existingWorkers.push(worker);
        }
        return worker;
    }
}
