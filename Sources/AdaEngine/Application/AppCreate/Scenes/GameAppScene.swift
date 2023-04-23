//
//  GameAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/14/22.
//

/// GameAppScene will present game scene in the pre-configured window.
/// You must use this type of scene if your application should launch a game scene.
public struct GameAppScene: AppScene {
    
    public typealias SceneBlock = () throws -> Scene
    
    public var scene: Never { fatalError() }
    
    private let gameScene: SceneBlock
    
    /// Create a new app scene from a game scene.
    public init(scene: @escaping SceneBlock) {
        self.gameScene = scene
    }
}

// MARK: - InternalAppScene

extension GameAppScene: InternalAppScene {
    func _makeWindow(with configuration: _AppSceneConfiguration) throws -> Window {
        let scene = try self.gameScene()
        
        let frame = Rect(origin: .zero, size: configuration.minimumSize)
        let window = Window(frame: frame)
        
        let gameSceneView = SceneView(scene: scene, frame: frame)
        window.addSubview(gameSceneView)
        
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        
        if let title = configuration.title {
            window.title = title
        }
        
        return window
    }
}
