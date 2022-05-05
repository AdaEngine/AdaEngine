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
            
        ]
        scripts: [],
        dependencies: [
            .project(target: "Vulkan", path: "../Vulkan"),
            .project(target: "Math", path: "../Math"),
            .external(name: "stb_image"),
            .external(name: "Collections")
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
    targets: targets
)
