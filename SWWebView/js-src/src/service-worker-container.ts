import EventTarget from "eventtarget";
import { StreamingXHR } from "./util/streaming-xhr";

class ServiceWorkerContainerImplementation extends EventTarget
    implements ServiceWorkerContainer {
    controller: ServiceWorker;
    oncontrollerchange: (ev: Event) => void;
    onmessage: (ev: Event) => void;
    ready: Promise<ServiceWorkerRegistration>;

    private dataFeed: EventSource;

    constructor() {
        super();
        this.dataFeed = new StreamingXHR("/service");
        this.dataFeed.addEventListener(
            "controllerchange",
            this.controllerChangeMessage
        );
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
        opts: RegistrationOptions
    ): Promise<ServiceWorkerRegistration> {
        throw new Error("not yet");
        // return new Promise<ServiceWorkerRegistration>(undefined);
    }
}

(navigator as any).serviceWorker = new ServiceWorkerContainerImplementation();
