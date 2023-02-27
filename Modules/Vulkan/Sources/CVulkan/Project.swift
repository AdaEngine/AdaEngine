//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "CVulkan",
    settings: .common,
    targets: [
        Target(
            name: "CVulkan",
            platform: .macOS,
            product: .framework,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).cvulkan",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            headers: .allHeaders(
                from: "cvulkan.h",
                umbrella: "module.modulemap"
            )
        )
    ]
)
