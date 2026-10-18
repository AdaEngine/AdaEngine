// swift-tools-version: 6.2
import PackageDescription
import Foundation

let package = Package(
    name: "AdaStudioCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.library(name: "AdaStudioCore", targets: ["AdaStudioCore"])],
    dependencies: [ProcessInfo.processInfo.environment["ADAENGINE_YAMS_PACKAGE_PATH"].map { .package(name: "Yams", path: $0) }
        ?? .package(url: "https://github.com/SpectralDragon/Yams.git", revision: "fb676da"),
        .package(url: "https://github.com/the-swift-collective/zlib.git", from: "1.3.2")],
    targets: [
        .target(name: "AdaStudioCore", dependencies: [.product(name: "Yams", package: "Yams"), .product(name: "ZLib", package: "zlib")]),
        .testTarget(name: "AdaStudioCoreTests", dependencies: ["AdaStudioCore"])
    ]
)
