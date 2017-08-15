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

    getRegistration(
        scope?: string
    ): Promise<ServiceWorkerRegistration | undefined> {
        return apiRequest<ServiceWorkerRegistrationAPIResponse | null>(
            "/ServiceWorkerContainer/getregistration",
            {
                scope: scope
            }
        ).then(response => {
            if (response === null) {
                return undefined;
            }
            return ServiceWorkerRegistrationImplementation.getOrCreate(
                response
            );
        });
    }

    getRegistrations(): Promise<ServiceWorkerRegistration[]> {
        return apiRequest<[ServiceWorkerRegistrationAPIResponse]>(
            "/ServiceWorkerContainer/getregistrations"
        ).then(response => {
            let registrations: ServiceWorkerRegistration[] = [];

            response.forEach(r => {
                if (r) {
                    registrations.push(
                        ServiceWorkerRegistrationImplementation.getOrCreate(r)
                    );
                }
            });

            return registrations;
        });
    }

    register(
        url: string,
        opts?: RegistrationOptions
    ): Promise<ServiceWorkerRegistration> {
        return apiRequest<
            ServiceWorkerRegistrationAPIResponse
        >("/ServiceWorkerContainer/register", {
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
