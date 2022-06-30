// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LibPNG",
    products: [
        .library(
            name: "LibPNG",
            targets: ["cpng"]
        )
    ],
    targets: [
        .systemLibrary(
            name: "cpng",
            pkgConfig: "libpng",
            providers: [
                .brewItem(["libpng"]),
                .aptItem(["libpng"])
            ]
        )
    ]
)
