// swift-tools-version: 5.7
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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "libpng",
            targets: ["libpng"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "libpng",
            sources: [
                "png.c",
                "pngerror.c",
                "pngget.c",
                "pngmem.c",
                "pngpread.c",
                "pngread.c",
                "pngrio.c",
                "pngrtran.c",
                "pngrutil.c",
                "pngset.c",
                "pngtrans.c",
                "pngwio.c",
                "pngwrite.c",
                "pngwtran.c",
                "pngwutil.c",
                "arm/arm_init.c",
                "arm/filter_neon_intrinsics.c",
                "arm/palette_neon_intrinsics.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("PNG_ARM_NEON_OPT", to: useNeon ? "2" : "0")
            ]),
        .testTarget(
            name: "libpngTests",
            dependencies: ["libpng"]),
    ]
)
