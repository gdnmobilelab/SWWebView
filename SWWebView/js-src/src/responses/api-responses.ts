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
