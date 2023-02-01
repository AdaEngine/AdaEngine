// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPIRV-Cross",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SPIRV-Cross",
            type: .static,
            targets: ["SPIRV-Cross"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SPIRV-Cross",
            dependencies: [],
            cxxSettings: [.define("SPIRV_CROSS_C_API_CPP"), .define("SPIRV_CROSS_C_API_GLSL"), .define("SPIRV_CROSS_C_API_HLSL"), .define("SPIRV_CROSS_C_API_MSL"), .define("SPIRV_CROSS_C_API_REFLECT")]
            )
    ],
    cLanguageStandard: .c11, cxxLanguageStandard: .cxx14
)
