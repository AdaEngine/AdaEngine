//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "Math",
    targets: [
        Target(
            name: "Math",
            platform: .macOS,
            product: .framework,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).math",
            deploymentTarget: .macOS(targetVersion: "11.0")
        )
    ]
)
