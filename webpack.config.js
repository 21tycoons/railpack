const webpack = require("webpack")
const path    = require("path")
const environments = {
  dev: "development",
  prod: "production"
}

module.exports = {
  mode: environments.prod,
  devtool: "none",
  entry: "./src/index.js",
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "[name].js",
    sourceMapFilename: "[file].map",
  },
  plugins: [],
}
