import EventEmitter from "tiny-emitter";
import { eventStream } from "../event-stream";
import { apiRequest } from "../util/api-request";
import {
    ServiceWorkerRegistrationAPIResponse,
    ServiceWorkerContainerAPIResponse
} from "../responses/api-responses";
import { ServiceWorkerRegistrationImplementation } from "../components/service-worker-registration";
import { ServiceWorkerImplementation } from "./service-worker";

class ServiceWorkerContainerImplementation extends EventEmitter
    implements ServiceWorkerContainer {
    // used for detection
    static __isSWWebViewImplementation = true;

    controller: ServiceWorker;
    oncontrollerchange: (ev: Event) => void;
    onmessage: (ev: Event) => void;
    ready: Promise<ServiceWorkerRegistration>;

    location: Location;

    constructor() {
        console.info(
            "Created new ServiceWorkerContainer for",
            window.location.pathname
        );
        super();
        this.location = window.location;

        (this as any).controller = null;

        let readyFulfill: ((ServiceWorkerRegistration) => void) | undefined;
        this.ready = new Promise((fulfill, reject) => {
            readyFulfill = fulfill;
        });

        this.addEventListener("controllerchange", e => {
            if (this.oncontrollerchange) {
                this.oncontrollerchange(e);
            }
        });

        eventStream.addEventListener<
            ServiceWorkerContainerAPIResponse
        >("serviceworkercontainer", e => {
            let reg = e.data.readyRegistration
                ? ServiceWorkerRegistrationImplementation.getOrCreate(
                      e.data.readyRegistration
                  )
                : undefined;

            if (reg && readyFulfill) {
                readyFulfill!(reg);
                readyFulfill = undefined;
            } else if (reg) {
                this.ready = Promise.resolve(reg);
            } else if (!readyFulfill) {
                this.ready = new Promise((fulfill, reject) => {
                    readyFulfill = fulfill;
                });
            }

            let newControllerInstance: ServiceWorker | null;

            if (e.data.controller) {
                newControllerInstance = ServiceWorkerImplementation.getOrCreate(
                    e.data.controller
                );
            } else {
                newControllerInstance = null;
            }

            if (newControllerInstance !== this.controller) {
                console.info(
                    "Set new controller from",
                    this.controller,
                    "to",
                    newControllerInstance
                );
                // Have to do 'as any' because TypeScript definition doesn't
                // allow null service workers
                (this as any).controller = newControllerInstance;
                let evt = new CustomEvent("controllerchange");
                this.dispatchEvent(evt);
            }
        });
        eventStream.open();
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
                path: window.location.pathname,
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
        return apiRequest<
            [ServiceWorkerRegistrationAPIResponse]
        >("/ServiceWorkerContainer/getregistrations", {
            path: window.location.pathname
        }).then(response => {
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
        console.info("Registering new worker at:", url);
        return apiRequest<
            ServiceWorkerRegistrationAPIResponse
        >("/ServiceWorkerContainer/register", {
            path: window.location.pathname,
            url: url,
            scope: opts ? opts!.scope : undefined
        }).then(response => {
            return ServiceWorkerRegistrationImplementation.getOrCreate(
                response
            );
        });
    }
}
if ("ServiceWorkerContainer" in self === false) {
    // We lazily initialize this when the client code requests it.
    let container: ServiceWorkerContainerImplementation | undefined = undefined;

    Object.defineProperty(navigator, "serviceWorker", {
        configurable: true,
        get() {
            if (container) {
                return container;
            }
            return (container = new ServiceWorkerContainerImplementation());
        }
    });
}
