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
            ProjectOpeningView()
        }
        .windowMode(.windowed)
        .windowTitle("AdaEditor")
        .windowTitleBar(WindowTitleBar(background: .transparent, reservesSafeArea: false, dragRegionHeight: 52))
        .windowTrafficLightOffset(x: 0, y: ProjectOpeningLayout.trafficLightOffsetY)
        .windowShadow(ProjectOpeningWindowConfiguration.hasShadow)
        .windowResizable(ProjectOpeningWindowConfiguration.isResizable)
        .minimumSize(width: ProjectOpeningLayout.windowWidth, height: ProjectOpeningLayout.windowHeight)
    }
}

public extension Foundation.Bundle {
    static var editor: Foundation.Bundle {
#if SWIFT_PACKAGE
        return Foundation.Bundle.module
#else
        return Foundation.Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE
class BundleToken {}
#endif
