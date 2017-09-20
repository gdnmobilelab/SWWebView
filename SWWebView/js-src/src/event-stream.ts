import { StreamingXHR } from "./util/streaming-xhr";

let eventsURL = new URL("/___events___", window.location.href);
eventsURL.searchParams.append(
    "path",
    window.location.pathname + window.location.search
);

export const eventStream = new StreamingXHR(eventsURL.href);
