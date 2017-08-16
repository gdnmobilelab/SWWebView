export interface ServiceWorkerAPIResponse {
    id: string;
    url: string;
    state: ServiceWorkerState;
}

export interface ServiceWorkerRegistrationAPIResponse {
    scope: string;
    id: string;
    unregsistered: boolean;
    active?: ServiceWorkerAPIResponse;
    waiting?: ServiceWorkerAPIResponse;
    installing?: ServiceWorkerAPIResponse;
    redundant?: ServiceWorkerAPIResponse;
}

export interface BooleanSuccessResponse {
    success: boolean;
}
