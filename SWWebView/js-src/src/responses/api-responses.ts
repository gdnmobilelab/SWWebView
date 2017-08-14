export { ServiceWorkerInstallState } from "../enum/enums";

export interface ServiceWorkerAPIResponse {
    id: string;
    url: string;
    state: ServiceWorkerInstallState;
}

export interface ServiceWorkerRegistrationAPIResponse {
    scope: string;
    active?: ServiceWorkerAPIResponse;
    waiting?: ServiceWorkerAPIResponse;
    installing?: ServiceWorkerAPIResponse;
    redundant?: ServiceWorkerAPIResponse;
}

export interface BooleanSuccessResponse {
    success: boolean;
}
