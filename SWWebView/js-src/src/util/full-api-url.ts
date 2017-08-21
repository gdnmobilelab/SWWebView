import { SW_PROTOCOL, SW_API_HOST } from "swwebview-settings";

export function getFullAPIURL(path) {
    return new URL(path, SW_PROTOCOL + "://" + SW_API_HOST).href;
}
