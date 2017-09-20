export interface ServiceWorkerAPIResponse {
    id: string;
    scriptURL: string;
    installState: ServiceWorkerState;
}

export interface ServiceWorkerContainerAPIResponse {
    readyRegistration?: ServiceWorkerRegistrationAPIResponse;
    controller?: ServiceWorkerAPIResponse;
}

export interface ServiceWorkerRegistrationAPIResponse {
    scope: string;
    id: string;
    unregistered: boolean;
    active?: ServiceWorkerAPIResponse;
    waiting?: ServiceWorkerAPIResponse;
    installing?: ServiceWorkerAPIResponse;
    redundant?: ServiceWorkerAPIResponse;
}

export interface BooleanSuccessResponse {
    success: boolean;
}

export interface WorkerInstallErrorAPIResponse {
    error: string;
    worker: ServiceWorkerAPIResponse;
}

export interface PostMessageResponse {
    transferred: string[];
}

export interface MessagePortAction {
    id: string;
    type: "message" | "close";
    data: any;
}

export interface PromiseReturn {
    promiseIndex: number;
    error?: string;
    response?: any;
}
