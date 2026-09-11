//
//  AdaEditorApp.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine
import Foundation
import Logging
#if canImport(AdaMCPPlugin)
import AdaMCPPlugin
#endif

@main
struct AdaEditorApp: App {
    init() {
        _ = EditorProjectOpenURLRouter.shared
        EditorAchievementBootstrap.install()
        let notifications = EditorNotificationCenter.shared
        notifications.onAction = { EditorNotificationRouter.shared.receive($0) }
        #if os(macOS) || os(iOS)
        EditorSystemNotifications.shared.install(on: notifications)
        #endif
        Task { await notifications.start() }
    }

    private static var mcpPort: Int {
        let value = CommandLine.arguments.first { $0.hasPrefix("--mcp-port=") }?.split(separator: "=").last
        guard let value, let port = Int(value), (0...65535).contains(port) else { return 2510 }
        return port
    }

    var body: some AppScene {
        WindowGroup {
            ProjectOpeningView()
        }
        .windowMode(.windowed)
        .windowTitle("AdaEngine Editor")
        .windowTitleBar(
            WindowTitleBar(
                background: .transparent,
                reservesSafeArea: EditorWindowSafeAreaPolicy.reservesSystemSafeArea,
                dragRegionHeight: 52
            )
        )
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
                port: Self.mcpPort,
                endpoint: "/mcp",
                serverName: "AdaEngine Editor",
                serverVersion: "0.1.0",
                instructions: """
                    Inspect and automate the live AdaEngine Editor. Use world.list_worlds to select Main or a SceneView subworld,
                    automation.capabilities for writable types, automation.run for YAML/JSON steps, logs.read for cursor-based logs,
                    and profiler.live_snapshot for metrics. Runtime ECS changes are not saved to scene files.
                    """
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
