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
//            .project(
//                target: "Vulkan",
//                path: .relativeToRoot("Sources/Vulkan")
//            ),
            .project(
                target: "Math",
                path: .relativeToRoot("Sources/Math")
            ),
            .external(name: "stb_image"),
            .external(name: "Collections"),
            .external(name: "Yams")
        ]
    ),
//    Target(
//        name: "AdaEngineTests",
//        platform: .macOS,
//        product: .unitTests,
//        bundleId: "dev.litecode.adaengine",
//        sources: ["Tests/**"],
//        dependencies: [
//            .target(name: "AdaEngine")
//        ]
//    )
]

let project = Project(
    name: "AdaEngine",
    settings: .adaEngine,
    targets: targets
)
