// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "UNIOCR",
  platforms: [
    .iOS(.v13),
    .macOS(SupportedPlatform.MacOSVersion.v10_15)
  ],
  products: [
    .library(
      name: "UNIOCR",
      targets: ["UNIOCR"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "UNIOCR",
      dependencies: []
    )
  ]
)
