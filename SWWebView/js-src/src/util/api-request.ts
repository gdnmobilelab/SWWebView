import { API_REQUEST_METHOD } from "swwebview-settings";
import { eventStream } from "../event-stream";
import { PromiseReturn } from "../responses/api-responses";

export class APIError extends Error {
    response: Response;

    constructor(message: string, response: Response) {
        super(message);
        this.response = response;
    }
}

interface StoredPromise {
    fulfill: (any) => void;
    reject: (Error) => void;
}

let storedPromises = new Map<number, StoredPromise>();

export function apiRequest<T>(path: string, body: any = undefined): Promise<T> {
    return eventStream.ready.then(() => {
        return new Promise<T>((fulfill, reject) => {
            let i = 0;
            while (storedPromises.has(i)) {
                i++;
            }
            storedPromises.set(i, { fulfill, reject });

            (window as any).webkit.messageHandlers["SWWebView"].postMessage({
                streamID: eventStream.id,
                promiseIndex: i,
                path: path,
                body: body
            });
        });

        // return fetch(path, {
        //     method: API_REQUEST_METHOD,
        //     body: body === undefined ? undefined : JSON.stringify(body),
        //     headers: {
        //         "Content-Type": "application/json"
        //     }
        // });
    });
    // .then(res => {
    //     if (res.ok === false) {
    //         if (res.status === 500) {
    //             return res.json().then(errorJSON => {
    //                 throw new Error(errorJSON.error);
    //             });
    //         }
    //         throw new APIError(
    //             "Received a non-200 response to API request",
    //             res
    //         );
    //     }
    //     return res.json();
    // });
}

eventStream.addEventListener<PromiseReturn>("promisereturn", e => {
    let promise = storedPromises.get(e.data.promiseIndex);
    if (!promise) {
        throw new Error("Trying to resolve a Promise that doesn't exist");
    }
    storedPromises.delete(e.data.promiseIndex);
    if (e.data.error) {
        promise.reject(new Error(e.data.error));
    }
    promise.fulfill(e.data.response);
});
