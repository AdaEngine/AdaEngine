//
//  InternalAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

// FIXME: We should avoid using fixed struct, instead we should pass some configuration context or hash map. Looks like it's a more extendable solution.

/// Describe default scene configuration settings for the app
struct _AppSceneConfiguration: Sendable {
    var minimumSize: Size = UIWindow.defaultMinimumSize
    var windowMode: UIWindow.Mode = .fullscreen
    var isSingleWindow: Bool = false
    var title: String?
    var useDefaultRenderPlugins: Bool = true
    var renderPlugins: [RenderWorldPlugin] = []
}

/// Helper interface for creating window from scene.
/// Each scene should conforms this protocol to avoid fatal error on start.
protocol InternalAppScene: Sendable {

    /// Create a window with given configuration.
    /// - Throws: Any error.
    /// - Returns: The configured window.
    @MainActor
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> UIWindow

    /// Collect all modification of default scene configuration.
    /// - NOTE: We use this method for ``SceneModifier`` interface.
    @MainActor
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration)
}

extension InternalAppScene {
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration) {}
}
