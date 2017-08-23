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

    private _controller: ServiceWorker | null = null;

    get controller() {
        if (this.receivedInitialProperties == false) {
            throw new Error(
                "You have attempted to access the controller property before it is ready. " +
                    "SWWebView has an initialisation delay - please access after using navigator.serviceWorker.ready"
            );
        }
        return this._controller!;
    }

    oncontrollerchange: (ev: Event) => void;
    onmessage: (ev: Event) => void;

    ready: Promise<ServiceWorkerRegistration>;
    private readyFulfill?: (ServiceWorkerRegistration) => void;

    location: Location;

    private receivedInitialProperties = false;

    constructor() {
        super();
        console.info(
            "Created new ServiceWorkerContainer for",
            window.location.href
        );
        this.location = window.location;

        let readyFulfill: ((ServiceWorkerRegistration) => void) | undefined;
        this.ready = new Promise((fulfill, reject) => {
            this.readyFulfill = fulfill;
        });

        this.addEventListener("controllerchange", e => {
            if (this.oncontrollerchange) {
                this.oncontrollerchange(e);
            }
        });

        if (eventStream.isOpen === false) {
            eventStream.open();
        }
    }

    updateFromAPIResponse(opts: ServiceWorkerContainerAPIResponse) {
        // set this so that client code can now successfully access controller
        this.receivedInitialProperties = true;

        if (opts.readyRegistration) {
            let reg = ServiceWorkerRegistrationImplementation.getOrCreate(
                opts.readyRegistration
            );

            reg.updateFromResponse(opts.readyRegistration!);

            if (this.readyFulfill) {
                this.readyFulfill(reg);
                this.readyFulfill = undefined;
            } else {
                this.ready = Promise.resolve(reg);
            }
        } else if (!this.readyFulfill) {
            this.ready = new Promise((fulfill, reject) => {
                this.readyFulfill = fulfill;
            });
        }

        let newControllerInstance: ServiceWorker | null;

        if (opts.controller) {
            newControllerInstance = ServiceWorkerImplementation.getOrCreate(
                opts.controller
            );
        } else {
            newControllerInstance = null;
        }

        if (newControllerInstance !== this._controller) {
            this._controller = newControllerInstance;
            let evt = new CustomEvent("controllerchange");
            this.dispatchEvent(evt);
        }
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

eventStream.addEventListener<
    ServiceWorkerContainerAPIResponse
>("serviceworkercontainer", e => {
    (navigator.serviceWorker as ServiceWorkerContainerImplementation).updateFromAPIResponse(
        e.data
    );
});

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
