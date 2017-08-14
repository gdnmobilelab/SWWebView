import EventEmitter from "tiny-emitter";
import { ServiceWorkerRegistrationAPIResponse } from "../responses/api-responses";
import { apiRequest } from "../util/api-request";
import { BooleanSuccessResponse } from "../responses/api-responses";

const existingRegistrations: ServiceWorkerRegistrationImplementation[] = [];

export class ServiceWorkerRegistrationImplementation extends EventEmitter
    implements ServiceWorkerRegistration {
    active: ServiceWorker | null;
    installing: ServiceWorker | null;
    waiting: ServiceWorker | null;

    pushManager: PushManager;
    scope: string;
    sync: SyncManager;

    constructor(opts: ServiceWorkerRegistrationAPIResponse) {
        super();
        this.scope = opts.scope;
    }

    static getOrCreate(opts: ServiceWorkerRegistrationAPIResponse) {
        let registration = existingRegistrations.find(
            reg => reg.scope == opts.scope
        );
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
        >("/serviceworkeregistration/unregister", {
            scope: this.scope
        }).then(response => {
            return response.success;
        });
    }

    update(): Promise<void> {
        throw new Error("not yet");
    }
}
