//
//  AdaEditorApp.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine
import Logging
#if canImport(AdaMCPPlugin)
import AdaMCPPlugin
#endif

@main
struct AdaEditorApp: App {
    var body: some AppScene {
        WindowGroup {
            ProjectOpeningView()
        }
        .windowMode(.windowed)
        .windowTitle("AdaEngine Editor")
        .windowTitleBar(WindowTitleBar(background: .transparent, reservesSafeArea: false, dragRegionHeight: 52))
        .windowTrafficLightOffset(x: 0, y: ProjectOpeningLayout.trafficLightOffsetY)
        .windowShadow(ProjectOpeningWindowConfiguration.hasShadow)
        .windowResizable(ProjectOpeningWindowConfiguration.isResizable)
        .minimumSize(width: ProjectOpeningLayout.windowWidth, height: ProjectOpeningLayout.windowHeight)
#if canImport(AdaMCPPlugin)
        .addPlugins(
            MCPPlugin(configuration: .init(
                enableHTTP: true,
                enableStdio: true,
                host: "127.0.0.1",
                port: 2510,
                endpoint: "/mcp",
                serverName: "AdaEngine Editor",
                serverVersion: "0.1.0",
                instructions: "Inspect the live AdaEngine Editor runtime."
            ))
        )
#endif
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
