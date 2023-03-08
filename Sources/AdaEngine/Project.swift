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
            "Assets/**/*.metal"
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
            .external(name: "Collections"),
            .external(name: "Yams"),
            .external(name: "box2d"),
            .sdk(name: "c++", type: .library)
        ],
        settings: .targetSettings(swiftFlags: [
            .define("MACOS"),
            .define("METAL"),
            .define("TUIST")
        ])
    ),
]

let project = Project(
    name: "AdaEngine",
    settings: .common,
    targets: targets
)
