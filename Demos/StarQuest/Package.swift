// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StarQuest",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "StarQuest", targets: ["StarQuest"])],
    dependencies: [.package(path: "../..")],
    targets: [
        .target(name: "StarQuestGame", dependencies: [.product(name: "AdaEngine", package: "AdaEngine")], resources: [.copy("../../Assets")]),
        .executableTarget(name: "StarQuest", dependencies: ["StarQuestGame", .product(name: "AdaEngine", package: "AdaEngine")]),
        .testTarget(name: "StarQuestGameTests", dependencies: ["StarQuestGame"])
    ]
)
