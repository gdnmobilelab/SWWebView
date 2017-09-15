import createConsoleInterceptor from "../../src/util/console-interceptor";
import { assert } from "chai";

describe("Console Interceptor", () => {
    it("Should intercept messages", function(done) {
        let interceptor = createConsoleInterceptor((level, args) => {
            assert.equal(level, "log");
            assert.equal(args[0], "hello");
            done();
        });

        interceptor.log("hello");
    });
});
