//
//  SceneModifier.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

/// Base interface that can decorate launch configurations.
protocol SceneModifier {
    func modify(_ configuration: inout _AppSceneConfiguration)
}

/// Modifier for app scene.
struct ModifiedScene<S: AppScene, V: SceneModifier>: AppScene {
    
    private let storedScene: S
    private let modifier: V
    
    init(storedScene: S, modifier: V) {
        self.storedScene = storedScene
        self.modifier = modifier
    }
    
    var scene: some AppScene {
        self.storedScene
    }
}

// MARK: - InternalAppScene

extension ModifiedScene: InternalAppScene {
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration) {
        self.modifier.modify(&configuration)
        
        // Recursive call for other modifiers
        (self.scene as? InternalAppScene)?._buildConfiguration(&configuration)
    }
    
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Window {
        try await (self.scene as! InternalAppScene)._makeWindow(with: configuration)
    }
}
