// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if (arch(arm64) || arch(arm))
let useNeon = true
#else
let useNeon = false
#endif

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
            cSettings: [
                .define("PNG_ARM_NEON_OPT", to: useNeon ? "2" : "0")
            ]
        )
    ],
    cxxLanguageStandard: .cxx14
)
