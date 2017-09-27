// import { assert } from "chai";
// import { API_REQUEST_METHOD } from "swwebview-settings";
// import { describeIfApp } from "../test-bootstrap";
// import { eventStream } from "../../src/event-stream";

// describeIfApp("Fetch grafts", () => {
//     xit("Grafts fetch bodies", () => {
//         return eventStream.ready
//             .then(() => {
//                 return fetch("/ping-with-body", {
//                     method: API_REQUEST_METHOD,
//                     body: JSON.stringify({ value: "test-string" })
//                 });
//             })
//             .then(res => res.json())
//             .then(json => {
//                 assert.equal(json.pong, "test-string");
//             });
//     });

//     xit("Grafts XMLHttpRequest bodies", done => {
//         return eventStream.ready.then(() => {
//             var xhttp = new XMLHttpRequest();
//             xhttp.onreadystatechange = function() {
//                 if (this.readyState == 4 && this.status == 200) {
//                     try {
//                         let data = JSON.parse(this.responseText);
//                         assert.equal(data.pong, "test-string");
//                     } catch (error) {
//                         done(error);
//                     }
//                     done();
//                 }
//             };
//             xhttp.open(
//                 API_REQUEST_METHOD,
//                 getFullAPIURL("/ping-with-body"),
//                 true
//             );
//             xhttp.send(JSON.stringify({ value: "test-string" }));
//         });
//     });
// });
