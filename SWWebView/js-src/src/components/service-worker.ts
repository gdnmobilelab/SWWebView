import EventEmitter from "tiny-emitter";
import {
    ServiceWorkerAPIResponse,
    WorkerInstallErrorAPIResponse
} from "../responses/api-responses";
import { eventStream } from "../event-stream";

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

eventStream.addEventListener<
    WorkerInstallErrorAPIResponse
>("workerinstallerror", e => {
    console.error(
        `Worker installation failed: ${e.data.error} (in ${e.data.worker
            .scriptURL})`
    );
});
