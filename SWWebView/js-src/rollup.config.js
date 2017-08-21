const typescriptPlugin = require("rollup-plugin-typescript");
const commonjs = require("rollup-plugin-commonjs");
const nodeResolve = require("rollup-plugin-node-resolve");
const typescript = require("typescript");

module.exports = {
    format: "iife",
    plugins: [
        typescriptPlugin({
            typescript: typescript,
            include: [__dirname + "/**/*.ts", __dirname + "/.gobble/**/*.ts"]
        }),
        commonjs({
            namedExports: {
                chai: ["assert"],
                "tiny-emitter": ["EventEmitter"]
            }
        }),
        nodeResolve({
            browser: true,
            preferBuiltins: false
        })
    ],
    sourceMap: true,
    moduleName: "swwebview",
    external: ["swwebview-settings"],
    globals: {
        "swwebview-settings": "swwebviewSettings"
    }
};
