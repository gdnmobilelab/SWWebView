import EventEmitter from "tiny-emitter";
import { StreamingXHR } from "./util/streaming-xhr";
import { apiRequest } from "./util/api-request";
import { ServiceWorkerRegistrationAPIResponse } from "./responses/api-responses";
import { ServiceWorkerRegistrationImplementation } from "./components/service-worker-registration";

class ServiceWorkerContainerImplementation extends EventEmitter
    implements ServiceWorkerContainer {
    controller: ServiceWorker;
    oncontrollerchange: (ev: Event) => void;
    onmessage: (ev: Event) => void;
    ready: Promise<ServiceWorkerRegistration>;

    location: Location;

    constructor() {
        super();
        this.location = window.location;
    }

    controllerChangeMessage(evt: MessageEvent) {
        console.log(evt);
    }

    getRegistration(scope?: string): Promise<ServiceWorkerRegistration> {
        throw new Error("not yet");
        // return new Promise<ServiceWorkerRegistration>(undefined);
    }

    getRegistrations(): Promise<ServiceWorkerRegistration[]> {
        throw new Error("not yet");
        // return new Promise<ServiceWorkerRegistration[]>([]);
    }

    register(
        url: string,
        opts?: RegistrationOptions
    ): Promise<ServiceWorkerRegistration> {
        return apiRequest<
            ServiceWorkerRegistrationAPIResponse
        >("/serviceworkercontainer/register", {
            url: url,
            scope: opts ? opts!.scope : undefined
        }).then(response => {
            return ServiceWorkerRegistrationImplementation.getOrCreate(
                response
            );
        });
    }
}

(navigator as any).serviceWorker = new ServiceWorkerContainerImplementation();
