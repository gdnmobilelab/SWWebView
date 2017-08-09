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
        body: JSON.stringify(body)
    }).then(res => {
        if (res.ok === false) {
            throw new APIError(
                "Received a non-200 response to API request",
                res
            );
        }
        return res.json();
    });
}
