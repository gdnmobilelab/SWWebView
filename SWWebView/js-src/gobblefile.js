const gobble = require("gobble");
const rollupConfig = require("./rollup.config");
const rollupTestConfig = require("./rollup.test.config");

rollupConfig.entry = "boot.ts";
rollupConfig.dest = "lib.js";
rollupConfig.banner = `;if (window.swwebviewSettings) {`;
rollupConfig.footer = ";};";
//livereload doesn't seem to work otherwise?
rollupConfig.format = "iife";

module.exports = gobble([
    gobble("tests").include(["tests.html", "fixtures/**"]),
    gobble("node_modules/mocha").include(["mocha.js", "mocha.css"]),
    gobble("src").transform("rollup", rollupConfig),
    gobble("tests").transform("rollup", rollupTestConfig)
]);
