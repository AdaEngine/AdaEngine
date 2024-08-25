//
//  AdaEditorApp.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine
import Logging

@main
struct AdaEditorApp: App {

    var scene: some AppScene {
        GameAppScene {
            UITestScene()
        }
//        GUIAppScene {
//            EditorWindow()
//        }
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
