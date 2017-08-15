import { API_REQUEST_METHOD } from "swwebview-settings";

export class APIError extends Error {
    response: Response;

    constructor(message: string, response: Response) {
        super(message);
        this.response = response;
    }
}

export function apiRequest<T>(path: string, body: any = undefined): Promise<T> {
    return fetch(path, {
        method: API_REQUEST_METHOD,
        body: body === undefined ? undefined : JSON.stringify(body),
        headers: {
            "Content-Type": "application/json"
        }
    }).then(res => {
        if (res.ok === false) {
            if (res.status === 500) {
                return res.json().then(errorJSON => {
                    throw new Error(errorJSON.error);
                });
            }
            throw new APIError(
                "Received a non-200 response to API request",
                res
            );
        }
        return res.json();
    });
}
