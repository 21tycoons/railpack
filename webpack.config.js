const webpack = require("webpack")
const path    = require("path")
const environments = {
  development: "development",
  production:  "production"
}

module.exports = {
  mode: environments.production,
  devtool: "none",
  entry: "./src/index.js",
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "[name].js",
    sourceMapFilename: "[file].map",
  },
  plugins: [],
}
