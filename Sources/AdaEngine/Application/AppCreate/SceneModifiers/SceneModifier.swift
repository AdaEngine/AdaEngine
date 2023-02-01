//
//  SceneModifier.swift
//  
//
//  Created by v.prusakov on 1/9/23.
//

protocol SceneModifier {
    func modify(_ configuration: inout _AppSceneConfiguration)
}

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
    
    func _makeWindow(with configuration: _AppSceneConfiguration) throws -> Window {
        try (self.scene as! InternalAppScene)._makeWindow(with: configuration)
    }
}
