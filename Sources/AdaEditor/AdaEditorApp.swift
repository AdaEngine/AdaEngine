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
    var body: some AppScene {
        WindowGroup {
            Text("See you later")
        }
        .addPlugins(
            DefaultPlugins()
        )
        .windowMode(.windowed)
        .windowTitle("AdaEngine")
    }
}

public extension Foundation.Bundle {
    static var editor: Foundation.Bundle {
#if SWIFT_PACKAGE && !BAZEL_BUILD
        return Foundation.Bundle.module
#else
        return Foundation.Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE || BAZEL_BUILD
class BundleToken {}
#endif
