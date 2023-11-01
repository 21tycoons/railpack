module.exports = {
  input: "src/index.js",
  output: {
    file: "app/javascript/application.js",
    format: "iife",
    inlineDynamicImports: true,
    sourcemap: false
  },
}
