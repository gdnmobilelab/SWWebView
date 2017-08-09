let baseConfig = require("./rollup.config.js");
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
                .map(
                    (filename, idx) => `import test_${idx} from '${filename}';`
                )
                .join("\n");

            let run =
                "\n\nexport default function() {" +
                allTests.map((filename, idx) => `test_${idx}();`).join("\n") +
                "}";

            return imports + run;
        },
        resolveId: function(imported, importee) {
            if (imported === "all-tests") {
                return "all-tests";
            }
        }
    };
}

baseConfig.plugins.push(loadAllTests());
baseConfig.plugins.push(
    replace({
        "process.env.NODE_DEBUG": "false"
    })
);
module.exports = baseConfig;
