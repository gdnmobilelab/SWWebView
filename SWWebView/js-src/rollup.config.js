const typescriptPlugin = require("rollup-plugin-typescript2");
const commonjs = require("rollup-plugin-commonjs");
const nodeResolve = require("rollup-plugin-node-resolve");
const typescript = require("typescript");

module.exports = {
    format: "iife",
    plugins: [
        typescriptPlugin(),
        commonjs({
            namedExports: {
                chai: ["assert"],
                "../../../git/tiny-emitter/index.js": ["EventEmitter"]
            }
        }),
        nodeResolve({
            browser: true,
            preferBuiltins: false
        })
    ],
    external: ["swwebview-settings"],
    globals: {
        "swwebview-settings": "swwebviewSettings"
    }
};
