import EventEmitter from "tiny-emitter";
import { ServiceWorkerRegistrationImplementation } from "./service-worker-registration";
import {
    ServiceWorkerAPIResponse,
    WorkerInstallErrorAPIResponse,
    PostMessageResponse
} from "../responses/api-responses";
import { eventStream } from "../event-stream";
import { apiRequest } from "../util/api-request";
import { serializeTransferables } from "../handlers/transferrable-converter";
import { addProxy } from "../handlers/messageport-manager";

const existingWorkers: ServiceWorkerImplementation[] = [];

export class ServiceWorkerImplementation extends EventEmitter
    implements ServiceWorker {
    id: string;
    scriptURL: string;
    state: ServiceWorkerState;
    onstatechange: (e) => void;
    onerror: (Error) => void;

    private registration: ServiceWorkerRegistrationImplementation;

    constructor(
        opts: ServiceWorkerAPIResponse,
        registration: ServiceWorkerRegistrationImplementation
    ) {
        super();
        this.updateFromAPIResponse(opts);
        this.registration = registration;
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

    postMessage(msg: any, transfer: any[] = []) {
        apiRequest<PostMessageResponse>("/ServiceWorker/postMessage", {
            id: this.id,
            registrationID: this.registration.id,
            message: serializeTransferables(msg, transfer),
            transferCount: transfer.length
        }).then(response => {
            // Register MessagePort proxies for all the transferables we just sent.
            response.transferred.forEach((id, idx) =>
                addProxy(transfer[idx], id)
            );
        });
    }

    static get(opts: ServiceWorkerAPIResponse) {
        return existingWorkers.find(w => w.id === opts.id);
    }

    static getOrCreate(
        opts: ServiceWorkerAPIResponse,
        registration: ServiceWorkerRegistrationImplementation
    ) {
        let existing = this.get(opts);
        if (existing) {
            return existing;
        } else {
            let newWorker = new ServiceWorkerImplementation(opts, registration);
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
