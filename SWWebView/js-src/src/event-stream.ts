import { StreamingXHR } from "./util/streaming-xhr";
import { getFullAPIURL } from "./util/full-api-url";

let absoluteURL = getFullAPIURL("/events");
let eventsURL = new URL(absoluteURL);
eventsURL.searchParams.append("path", window.location.pathname);

export const eventStream = new StreamingXHR(eventsURL.href);
