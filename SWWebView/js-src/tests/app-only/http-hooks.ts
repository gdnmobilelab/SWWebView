import { apiRequest, APIError } from "../../src/util/api-request";
import { assert } from "chai";
import { StreamingXHR } from "../../src/util/streaming-xhr";
import { log } from "../native-console";

export default function() {
    describe("Basic HTTP hooks for Service Worker API", () => {
        it("Returns 404 when trying to access a URL we don't know", () => {
            return apiRequest("/does_not_exist").catch((error: APIError) => {
                assert.equal(error.response.status, 404);
            });
        });
        it("Returns JSON response when URL is known", () => {
            return apiRequest<any>("/ping").then(json => {
                assert.equal(json.pong, true);
            });
        });

        it("Can use a streaming XHR request", function(done) {
            let stream = new StreamingXHR("/stream");
            stream.addEventListener("test-event", (ev: MessageEvent) => {
                assert.equal(ev.data.test, "hello");
                stream.close();
                done();
            });
            stream.addEventListener("error", (ev: ErrorEvent) => {
                done(ev.error);
            });
        });
    });
}
