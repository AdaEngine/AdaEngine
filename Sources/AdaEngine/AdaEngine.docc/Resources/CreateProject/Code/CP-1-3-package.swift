// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CreateFirstProject",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "CreateFirstProject",
            targets: ["CreateFirstProject"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/AdaEngine/AdaEngine", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "CreateFirstProject",
            dependencies: [
                "AdaEngine"
            ]),
        .testTarget(
            name: "CreateFirstProjectTests",
            dependencies: ["CreateFirstProject"]),
    ]
)
