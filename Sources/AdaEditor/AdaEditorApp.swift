//
//  AdaEditorApp.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine

@main
struct AdaEditorApp: App {
    
    let gameScene = GameScene2D()
    
    var scene: some AppScene {
        GameAppScene {
            try await gameScene.makeScene()
        }
        .windowMode(.windowed)
        .windowTitle("AdaEngine")
    }
}

public extension Bundle {
    static var editor: Bundle {
#if SWIFT_PACKAGE && !BAZEL_BUILD
        return Bundle.module
#else
        return Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE || BAZEL_BUILD
class BundleToken {}
#endif
