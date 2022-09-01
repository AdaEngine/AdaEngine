// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cstb",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "stb_c_lexer",
            targets: ["stb_c_lexer"]),
        .library(
            name: "stb_connected_components",
            targets: ["stb_connected_components"]),
        .library(
            name: "stb_divide",
            targets: ["stb_divide"]),
        .library(
            name: "stb_ds",
            targets: ["stb_ds"]),
        .library(
            name: "stb_dxt",
            targets: ["stb_dxt"]),
        .library(
            name: "stb_easy_font",
            targets: ["stb_easy_font"]),
        .library(
            name: "stb_herringbone_wang_tile",
            targets: ["stb_herringbone_wang_tile"]),
        .library(
            name: "stb_hexwave",
            targets: ["stb_hexwave"]),
        .library(
            name: "stb_image",
            targets: ["stb_image"]),
        .library(
            name: "stb_image_resize",
            targets: ["stb_image_resize"]),
        .library(
            name: "stb_image_write",
            targets: ["stb_image_write"]),
        .library(
            name: "stb_include",
            targets: ["stb_include"]),
        .library(
            name: "stb_perlin",
            targets: ["stb_perlin"]),
        .library(
            name: "stb_rect_pack",
            targets: ["stb_rect_pack"]),
        .library(
            name: "stb_truetype",
            targets: ["stb_truetype"]),
        .library(
            name: "stb_vorbis",
            targets: ["stb_vorbis"]),
        .library(
            name: "stb_voxel_render",
            targets: ["stb_voxel_render"]),
        .library(
            name: "miniz",
            targets: ["miniz"]),
        .library(
            name: "tinyexr",
            targets: ["tinyexr"]),
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .target(
            name: "stb_c_lexer",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_connected_components",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_divide",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_ds",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_dxt",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_easy_font",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_herringbone_wang_tile",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_hexwave",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_image",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_image_resize",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_image_write",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_include",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_perlin",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_rect_pack",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_truetype",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_vorbis",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "stb_voxel_render",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "miniz",
            dependencies: [],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
        .target(
            name: "tinyexr",
            dependencies: ["miniz"],
            cSettings: [.define("NDEBUG", .when(configuration: .release))]),
    ]
)
