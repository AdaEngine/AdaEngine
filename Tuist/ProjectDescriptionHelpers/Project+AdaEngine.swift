//
//  Project+AdaEngine.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription

public extension Settings {
    static var adaEngine: Settings {
        Settings.settings(base: [
            "PRODUCT_BUNDLE_IDENTIFIER": "dev.litecode.adaengine",
        ])
    }
}
