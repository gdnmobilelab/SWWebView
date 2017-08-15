import { StreamingXHR } from "./util/streaming-xhr";

export const eventStream = new StreamingXHR("/events");

eventStream.addEventListener("serviceworkerregistration", console.info);
