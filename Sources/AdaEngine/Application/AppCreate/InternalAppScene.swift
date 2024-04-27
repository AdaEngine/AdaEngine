//
//  InternalAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

// FIXME: We should avoid using fixed struct, instead we should pass some configuration context or hash map. Looks like it's a more extendable solution.

/// Describe default scene configuration settings for the app
struct _AppSceneConfiguration {
    var minimumSize: Size = Window.defaultMinimumSize
    var windowMode: Window.Mode = .fullscreen
    var isSingleWindow: Bool = false
    var title: String?
    var useDefaultRenderPlugins: Bool = true
    var plugins: [ScenePlugin] = []
}

/// Helper interface for creating window from scene.
/// Each scene should conforms this protocol to avoid fatal error on start.
@MainActor
protocol InternalAppScene {

    /// Create a window with given configuration.
    /// - Throws: Any error.
    /// - Returns: The configured window.
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Window
    
    /// Collect all modification of default scene configuration.
    /// - NOTE: We use this method for ``SceneModifier`` interface.
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration)
}

extension InternalAppScene {
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration) {}
}
