//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let targets: [Target] = [
    Target(
        name: "AdaEngine",
        platform: .macOS,
        product: .framework,
        bundleId: .bundleIdentifier(name: "engine"),
        deploymentTarget: .macOS(targetVersion: "11.0"),
        sources: [
            .glob("**/*.swift", excluding: ["Project.swift"])
        ],
        resources: [
            "Assets/**/*",
        ],
        scripts: [],
        dependencies: [
            .project(
                target: "Math",
                path: .relativeToRoot("Sources/Math")
            ),
            .project(
                target: "libpng",
                path: .relativeToRoot("Sources/libpng")
            ),
            .project(
                target: "AtlasFontGenerator",
                path: .relativeToRoot("Sources/AtlasFontGenerator")
            ),
            .project(
                target: "SPIRVCompiler",
                path: .relativeToRoot("Sources/SPIRVCompiler")
            ),
            .project(
                target: "AdaBox2d",
                path: .relativeToRoot("Sources/AdaBox2d")
            ),
            .external(name: "Collections"),
            .external(name: "Yams"),
            .package(product: "SPIRV-Cross"),
            .sdk(name: "c++", type: .library)
        ],
        settings: .targetSettings(swiftFlags: [
            .define("MACOS"),
            .define("METAL"),
            .define("TUIST"),
            .experementalCXXInterop
        ])
    ),
]

let project = Project(
    name: "AdaEngine",
    packages: [
        .remote(
            url: "https://github.com/AdaEngine/SPIRV-Cross",
            requirement: .branch("main")
        )
    ],
    settings: .common,
    targets: targets
)
