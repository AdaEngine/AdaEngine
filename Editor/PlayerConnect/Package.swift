// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AdaPlayerConnect",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.library(name: "AdaPlayerConnect", targets: ["AdaPlayerConnect"])],
    targets: [
        .target(name: "CWindowsPlayer", linkerSettings: [.linkedLibrary("ws2_32", .when(platforms: [.windows])), .linkedLibrary("dnsapi", .when(platforms: [.windows]))]),
        .target(name: "AdaPlayerConnect", dependencies: [.target(name: "CWindowsPlayer", condition: .when(platforms: [.windows]))]),
        .testTarget(name: "AdaPlayerConnectTests", dependencies: ["AdaPlayerConnect"])
    ]
)
