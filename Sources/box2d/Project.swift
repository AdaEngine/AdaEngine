//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "box2d",
    settings: .common,
    targets: [
        Target(
            name: "box2d",
            platform: .macOS,
            product: .framework,
            productName: "box2d",
            bundleId: .bundleIdentifier(name: "box2d"),
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("**/*", excluding: ["Project.swift"])
            ]
        )
    ]
)
