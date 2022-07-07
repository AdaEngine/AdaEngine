// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "libpng",
    products: [
        .library(
            name: "libpng",
            targets: ["libpng"]
        )
    ],
    targets: [
        .target(
            name: "libpng",
            publicHeadersPath: "."
        )
    ],
    cLanguageStandard: .c11
)
