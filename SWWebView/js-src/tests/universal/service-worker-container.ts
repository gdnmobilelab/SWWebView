import { assert } from "chai";

export default function() {
    describe("Service Worker Container", () => {
        it("Should register a service worker", () => {
            return navigator.serviceWorker.register("/test-worker.js");
        });
    });
}
