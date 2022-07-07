// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "box2d",
    products: [
        .library(
            name: "box2d",
            targets: ["box2d"]
        )
    ],
    targets: [
        .target(name: "box2d")
    ],
    cxxLanguageStandard: .cxx11
)
