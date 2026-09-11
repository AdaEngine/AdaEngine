// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Fold",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Fold", targets: ["Fold"])],
    dependencies: [.package(path: "../..")],
    targets: [
        .target(
            name: "FoldGame",
            dependencies: [.product(name: "AdaEngine", package: "AdaEngine")],
            resources: [.copy("../../Assets")],
            plugins: [.plugin(name: "AdaScriptBuildPlugin", package: "AdaEngine")]
        ),
        .executableTarget(name: "Fold", dependencies: ["FoldGame"]),
        .testTarget(name: "FoldGameTests", dependencies: ["FoldGame"])
    ]
)
