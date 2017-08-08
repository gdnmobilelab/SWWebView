const typescriptPlugin = require("rollup-plugin-typescript");
const typescript = require("typescript");

module.exports = {
  entry: "./src/boot.ts",
  dest: "../SWWebView/js-dist/runtime.js",
  format: "iife",
  plugins: [
    typescriptPlugin({
      typescript
    })
  ]
};
