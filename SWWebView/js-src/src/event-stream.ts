import { StreamingXHR } from "./util/streaming-xhr";
import { EVENT_STREAM_PATH } from "swwebview-settings";

let eventsURL = new URL(EVENT_STREAM_PATH, window.location.href);
eventsURL.searchParams.append(
    "path",
    window.location.pathname + window.location.search
);

export const eventStream = new StreamingXHR(eventsURL.href);
