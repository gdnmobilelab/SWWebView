import EventEmitter from "tiny-emitter";
import { ServiceWorkerRegistrationAPIResponse } from "../responses/api-responses";
import { apiRequest } from "../util/api-request";
import { BooleanSuccessResponse } from "../responses/api-responses";
import { eventStream } from "../event-stream";
import { ServiceWorkerImplementation } from "./service-worker";

const existingRegistrations: ServiceWorkerRegistrationImplementation[] = [];

export class ServiceWorkerRegistrationImplementation extends EventEmitter
    implements ServiceWorkerRegistration {
    active: ServiceWorker | null;
    installing: ServiceWorker | null;
    waiting: ServiceWorker | null;

    pushManager: PushManager;
    scope: string;
    id: string;
    sync: SyncManager;

    constructor(opts: ServiceWorkerRegistrationAPIResponse) {
        super();
        this.scope = opts.scope;
        this.id = opts.id;
        this.updateFromResponse(opts);
    }

    static getOrCreate(opts: ServiceWorkerRegistrationAPIResponse) {
        let registration = existingRegistrations.find(reg => reg.id == opts.id);
        if (!registration) {
            if (opts.unregistered === true) {
                throw new Error(
                    "Trying to create an unregistered registration"
                );
            }
            console.info("Creating new registration:", opts.id, opts);
            registration = new ServiceWorkerRegistrationImplementation(opts);
            existingRegistrations.push(registration);
        }
        return registration;
    }

    updateFromResponse(opts: ServiceWorkerRegistrationAPIResponse) {
        if (opts.unregistered === true) {
            console.info("Removing inactive registration:", opts.id);
            // Remove from our array of existing registrations, as we don't
            // want to refer to this again.
            let idx = existingRegistrations.indexOf(this);
            existingRegistrations.splice(idx, 1);
            return;
        }

        this.active = opts.active
            ? ServiceWorkerImplementation.getOrCreate(opts.active, this)
            : null;
        this.installing = opts.installing
            ? ServiceWorkerImplementation.getOrCreate(opts.installing, this)
            : null;
        this.waiting = opts.waiting
            ? ServiceWorkerImplementation.getOrCreate(opts.waiting, this)
            : null;
    }

    onupdatefound: () => void;

    getNotifications() {
        throw new Error("not yet");
    }

    showNotification(
        title: string,
        options?: NotificationOptions
    ): Promise<void> {
        throw new Error("not yet");
    }

    unregister(): Promise<boolean> {
        return apiRequest<
            BooleanSuccessResponse
        >("/ServiceWorkerRegistration/unregister", {
            id: this.id
        }).then(response => {
            return response.success;
        });
    }

    update(): Promise<void> {
        throw new Error("not yet");
    }
}

eventStream.addEventListener<
    ServiceWorkerRegistrationAPIResponse
>("serviceworkerregistration", e => {
    console.log("reg update", e.data);
    let reg = existingRegistrations.find(r => r.id == e.data.id);
    if (reg) {
        reg.updateFromResponse(e.data);
    } else {
        console.info(
            "Received update for non-existent registration",
            e.data.id
        );
    }
});
