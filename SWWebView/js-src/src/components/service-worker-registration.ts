import EventEmitter from "tiny-emitter";
import { ServiceWorkerRegistrationAPIResponse } from "../responses/api-responses";

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
        throw new Error("not yet");
    }

    update(): Promise<void> {
        throw new Error("not yet");
    }
}
