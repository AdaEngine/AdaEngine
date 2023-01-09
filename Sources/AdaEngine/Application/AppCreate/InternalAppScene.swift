//
//  InternalAppScene.swift
//  
//
//  Created by v.prusakov on 1/9/23.
//

/// Describe default scene configuration settings for the app
struct _AppSceneConfiguration {
    var minimumSize: Size = Window.defaultMinimumSize
    var windowMode: Window.Mode = .fullscreen
    var isSingleWindow: Bool = false
    var title: String?
}

/// Helper interface for creating window from scene.
/// Each scene should conforms this protocol to avoid fatal error on start.
protocol InternalAppScene {
    
    /// Create a window with given configuration.
    /// - Throws: Any error.
    /// - Returns: The configured window.
    func _makeWindow(with configuration: _AppSceneConfiguration) throws -> Window
    
    /// Collect all modification of default scene configuration.
    /// - NOTE: We use this method for `SceneModifier` interface.
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration)
}

extension InternalAppScene {
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration) {}
}
