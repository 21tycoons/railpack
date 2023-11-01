const webpack = require("webpack")
const path = require("path")
const envs = {
  dev: "development",
  prod: "production"
}

module.exports = {
  mode: envs.prod,
  devtool: "source-map",
  entry: "./src/index.js",
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "[name].js",
    sourceMapFilename: "[file].map",
  },
  plugins: [],
}
