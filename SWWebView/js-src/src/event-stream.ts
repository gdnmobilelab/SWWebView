import { StreamingXHR } from "./util/streaming-xhr";

let eventsURL = new URL("/events", window.location.href);
eventsURL.searchParams.append(
    "path",
    window.location.pathname + window.location.search
);

export const eventStream = new StreamingXHR(eventsURL.href);
