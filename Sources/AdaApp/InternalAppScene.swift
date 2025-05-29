//
//  InternalAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

import AdaECS
import Math

// FIXME: We should avoid using fixed struct, instead we should pass some configuration context or hash map. Looks like it's a more extendable solution.

public enum WindowMode: UInt64, Sendable {
    case windowed
    case fullscreen
}

/// Describe default scene configuration settings for the app
public struct _AppSceneConfiguration {
    public var minimumSize: Size = Size(width: 800, height: 600)
    public var windowMode: WindowMode = .fullscreen
    public var isSingleWindow: Bool = false
    public var title: String?
    public var appBuilder: AppWorlds = AppWorlds(mainWorld: World(), subWorlds: [:])
}

/// Helper interface for creating window from scene.
/// Each scene should conforms this protocol to avoid fatal error on start.
public protocol InternalAppScene: Sendable {
//
//    /// Create a window with given configuration.
//    /// - Throws: Any error.
//    /// - Returns: The configured window.
    @MainActor
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Any

    /// Collect all modification of default scene configuration.
    /// - NOTE: We use this method for ``SceneModifier`` interface.
    @MainActor
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration)

    @MainActor
    func _getFilePath() -> StaticString
}

public extension InternalAppScene {
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration) {}
}
