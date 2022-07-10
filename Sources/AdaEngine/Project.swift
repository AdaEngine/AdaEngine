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
        bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER)",
        deploymentTarget: .macOS(targetVersion: "11.0"),
        sources: [
            .glob("**/*", excluding: ["Project.swift"])
        ],
        scripts: [],
        dependencies: [
            .project(
                target: "Math",
                path: .relativeToRoot("Sources/Math")
            ),
            .project(
                target: "Physics",
                path: .relativeToRoot("Sources/Physics")
            ),
            .project(
                target: "libpng",
                path: .relativeToRoot("ThirdParty/libpng")
            ),
            .external(name: "stb_image"),
            .external(name: "Collections"),
            .external(name: "Yams"),
        ],
        settings: .adaEngine
    ),
]

let project = Project(
    name: "AdaEngine",
    settings: .adaEngine,
    targets: targets
)
