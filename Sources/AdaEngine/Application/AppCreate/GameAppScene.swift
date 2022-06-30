//
//  GameAppScene.swift
//  
//
//  Created by v.prusakov on 6/14/22.
//

public struct GameAppScene: AppScene {
    
    public typealias SceneBlock = () async throws -> Scene
    
    public var scene: Never { fatalError() }
    
    public var _configuration = _AppSceneConfiguration()
    let gameScene: SceneBlock
    
    public init(scene: @escaping SceneBlock) {
        self.gameScene = scene
    }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Window {
        let scene = try await self.gameScene()
        let window = Window(scene: scene, frame: Rect(origin: .zero, size: configuration.minimumSize))
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        return window
    }
}
