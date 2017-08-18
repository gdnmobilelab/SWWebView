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
        this.active = opts.active
            ? ServiceWorkerImplementation.getOrCreate(opts.active)
            : null;
        this.installing = opts.installing
            ? ServiceWorkerImplementation.getOrCreate(opts.installing)
            : null;
        this.waiting = opts.waiting
            ? ServiceWorkerImplementation.getOrCreate(opts.waiting)
            : null;
    }

    static getOrCreate(opts: ServiceWorkerRegistrationAPIResponse) {
        let registration = existingRegistrations.find(reg => reg.id == opts.id);
        if (!registration) {
            registration = new ServiceWorkerRegistrationImplementation(opts);
            existingRegistrations.push(registration);
        }
        return registration;
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
            scope: this.scope,
            id: this.id
        }).then(response => {
            return response.success;
        });
    }

    update(): Promise<void> {
        throw new Error("not yet");
    }
}

eventStream.addEventListener("serviceworkerregistration", console.info);
