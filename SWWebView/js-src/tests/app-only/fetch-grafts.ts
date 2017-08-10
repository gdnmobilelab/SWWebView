import { assert } from "chai";
import { API_REQUEST_METHOD } from "swwebview-settings";

export default function() {
    describe("Fetch grafts", () => {
        it("Grafts fetch bodies", () => {
            return fetch("/ping-with-body", {
                method: API_REQUEST_METHOD,
                body: JSON.stringify({ value: "test-string" })
            })
                .then(res => res.json())
                .then(json => {
                    assert.equal(json.pong, "test-string");
                });
        });

        it("Grafts XMLHttpRequest bodies", done => {
            var xhttp = new XMLHttpRequest();
            xhttp.onreadystatechange = function() {
                if (this.readyState == 4 && this.status == 200) {
                    try {
                        let data = JSON.parse(this.responseText);
                        assert.equal(data.pong, "test-string");
                    } catch (error) {
                        done(error);
                    }
                    done();
                }
            };
            xhttp.open(API_REQUEST_METHOD, "/ping-with-body", true);
            xhttp.send(JSON.stringify({ value: "test-string" }));
        });
    });
}
