//
//  Workspace.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: "AdaEngine",
    projects: [
        "Sources/AdaEngine",
        "Sources/AdaEditor",
        "Sources/Math",
        "Sources/Physics"
    ]
)
