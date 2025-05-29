//
//  SceneModifier.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

/// Base interface that can decorate launch configurations.
protocol SceneModifier {
    @MainActor
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
    
    var body: some AppScene {
        self.storedScene
    }
}

// MARK: - InternalAppScene

extension ModifiedScene: InternalAppScene {
    func _buildConfiguration(_ configuration: inout _AppSceneConfiguration) {
        self.modifier.modify(&configuration)
        
        // Recursive call for other modifiers
        (self.body as? InternalAppScene)?._buildConfiguration(&configuration)
    }
    
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Any {
        try await (self.body as! InternalAppScene)._makeWindow(with: configuration)
    }

    func _getFilePath() -> StaticString {
        (self.body as? InternalAppScene)?._getFilePath() ?? #filePath
    }
}
