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
    onstatechange: (e) => void;
    onerror: (Error) => void;

    constructor(opts: ServiceWorkerAPIResponse) {
        super();
        this.updateFromAPIResponse(opts);
        this.id = opts.id;

        this.addEventListener("statechange", e => {
            if (this.onstatechange) {
                this.onstatechange(e);
            }
        });
    }

    updateFromAPIResponse(opts: ServiceWorkerAPIResponse) {
        this.scriptURL = opts.scriptURL;
        let oldState = this.state;
        this.state = opts.installState;

        if (oldState !== this.state) {
            let evt = new CustomEvent("statechange");
            this.dispatchEvent(evt);
        }
    }

    postMessage() {}

    static get(opts: ServiceWorkerAPIResponse) {
        return existingWorkers.find(w => w.id === opts.id);
    }

    static getOrCreate(opts: ServiceWorkerAPIResponse) {
        let existing = this.get(opts);
        if (existing) {
            return existing;
        } else {
            let newWorker = new ServiceWorkerImplementation(opts);
            existingWorkers.push(newWorker);
            return newWorker;
        }
    }
}

eventStream.addEventListener<ServiceWorkerAPIResponse>("serviceworker", e => {
    let existingWorker = ServiceWorkerImplementation.get(e.data);
    console.info("Worker update:", e.data);
    if (existingWorker) {
        existingWorker.updateFromAPIResponse(e.data);
    }
});

eventStream.addEventListener<
    WorkerInstallErrorAPIResponse
>("workerinstallerror", e => {
    console.error(
        `Worker installation failed: ${e.data.error} (in ${e.data.worker
            .scriptURL})`
    );
});
