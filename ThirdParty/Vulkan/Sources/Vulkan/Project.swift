//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "Vulkan",
    settings: .adaEngine,
    targets: [
        Target(
            name: "Vulkan",
            platform: .macOS,
            product: .framework,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).vulkan",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("**/*", excluding: ["Project.swift"])
            ],
            dependencies: [
                .project(
                    target: "CVulkan",
                    path: .relativeToRoot("Sources/CVulkan")
                )
            ]
        )
    ]
)
