import { apiRequest, APIError } from "../../src/util/api-request";
import { assert } from "chai";
import { StreamingXHR } from "../../src/util/streaming-xhr";
import { describeIfApp } from "../test-bootstrap";
import { API_REQUEST_METHOD, EVENT_STREAM_PATH } from "swwebview-settings";

describeIfApp("Basic HTTP hooks for Service Worker API", () => {
    it("Returns 404 when trying to access a command we don't know", () => {
        return apiRequest("/does_not_exist").catch((error: APIError) => {
            assert.equal(error.message, "Route not found");
        });
    });

    it("Returns JSON response when URL is known", () => {
        return apiRequest<any>("/ping").then(json => {
            assert.equal(json.pong, true);
        });
    });

    it("Can use a streaming XHR request", function(done) {
        let stream = new StreamingXHR(EVENT_STREAM_PATH + "?path=/");
        stream.open();
        stream.addEventListener(
            "serviceworkercontainer",
            (ev: MessageEvent) => {
                assert.equal(ev.data.readyRegistration, null);
                stream.close();
                done();
            }
        );
        // stream.addEventListener("test-event2", (ev: MessageEvent) => {
        //     assert.equal(ev.data.test, "hello2");
        //     assert.equal(receivedFirstEvent, true);
        //     stream.close();
        //     done();
        // });
        // stream.addEventListener("error", (ev: ErrorEvent) => {
        //     done(ev.error);
        // });
    });
});
