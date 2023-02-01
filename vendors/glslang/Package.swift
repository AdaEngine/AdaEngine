// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var excludeOSDependent: [String: [String]] = [
    "Unix": [
        "ossource.cpp"
    ],
    "Web": [
        "glslang.after.js",
        "glslang.js.cpp",
        "glslang.pre.js"
    ],
    "Windows": [
        "main.cpp",
        "ossource.cpp"
    ]
]

#if os(Linux)
excludeOSDependent["Unix"] = nil
#elseif os(WASI)
excludeOSDependent["Web"] = nil
#elseif os(Windows)
excludeOSDependent["Windows"] = nil
#endif

// Add OSDependent path here
let exclude = excludeOSDependent
    .map { platform, files -> [String] in
        files.map { String(format: "glslang/OSDependent/%@/%@", platform, $0) }
    }
    .flatMap { $0 }

let package = Package(
    name: "glslang",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "glslang",
            type: .dynamic,
            targets: ["glslang"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "glslang",
            path: ".",
            exclude: exclude,
            publicHeadersPath: ".",
            cxxSettings: [
                .define("__EMSCRIPTEN__", to: "1", .when(platforms: [.wasi])),
                .define("GLSLANG_WEB", to: "1", .when(platforms: [.wasi])),
                .define("_WIN32", to: "1", .when(platforms: [.windows])),
                //                .define("ENABLE_HLSL")
                .define("ENABLE_OPT", to: "0")
            ]
        )
    ],
//    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx11
)
