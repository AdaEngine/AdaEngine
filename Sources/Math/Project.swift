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
    settings: .common,
    targets: [
        Target(
            name: "Math",
            platform: .macOS,
            product: .framework,
            bundleId: .bundleIdentifier(name: "math"),
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("**/*", excluding: ["Project.swift"])
            ]
        ),
        Target(
            name: "MathTests",
            platform: .macOS,
            product: .unitTests,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).math",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob(.relativeToRoot("Tests/MathTests/**/*"))
            ]
        )
    ]
)
