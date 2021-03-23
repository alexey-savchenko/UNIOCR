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
  dependencies: [
    .package(
      url: "https://github.com/alexey-savchenko/UNILib.git",
      Package.Dependency.Requirement.branch("main")
    ),
    .package(
      url: "https://github.com/Moya/Moya.git",
      .upToNextMajor(from: "14.0.0")
    )
  ],
  targets: [
    .target(
      name: "UNIOCR",
      dependencies: ["Moya", "UNILib"]
    )
  ]
)
