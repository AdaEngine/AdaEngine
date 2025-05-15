// swift-tools-version: 6.0
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
            targets: ["libpng"]),
    ],
    dependencies: [
        .package(url: "https://github.com/the-swift-collective/zlib.git", from: "1.3.1")
    ],
    targets: [
        .target(
            name: "libpng",
            dependencies: [
                .product(name: "ZLib", package: "zlib"),
            ],
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
            ])
    ]
)
