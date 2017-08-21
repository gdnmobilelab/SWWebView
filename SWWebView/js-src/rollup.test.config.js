let baseConfig = Object.assign({}, require("./rollup.config.js"));
const fs = require("fs");
const recursiveReadSync = require("recursive-readdir-sync");
const path = require("path");
const replace = require("rollup-plugin-replace");

function loadAllTests() {
    return {
        name: "TestLoader",
        load: id => {
            if (id !== "all-tests") {
                return;
            }

            let allTests = recursiveReadSync(
                path.join(__dirname, "tests", "app-only")
            )
                .concat(
                    recursiveReadSync(
                        path.join(__dirname, "tests", "universal")
                    )
                )
                .filter(file => path.extname(file) === ".ts");

            let imports = allTests
                .map((filename, idx) => `import '${filename}';`)
                .join("\n");

            return imports;
        },
        resolveId: function(imported, importee) {
            if (imported === "all-tests") {
                return "all-tests";
            }
        }
    };
}
baseConfig.entry = "test-bootstrap.ts";
baseConfig.dest = "tests.js";
baseConfig.plugins.push(loadAllTests());
baseConfig.format = "umd";

module.exports = baseConfig;
