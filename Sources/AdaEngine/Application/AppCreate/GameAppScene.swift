//
//  GameAppScene.swift
//  
//
//  Created by v.prusakov on 6/14/22.
//

public struct GameAppScene: AppScene {
    
    public var scene: Never { fatalError() }
    
    public var _configuration = _AppSceneConfiguration()
    let gameScene: () -> Scene
    
    public init(scene: @escaping () -> Scene) {
        self.gameScene = scene
    }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) -> Window {
        let scene = self.gameScene()
        let window = Window(scene: scene, frame: Rect(origin: .zero, size: configuration.minimumSize))
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        return window
    }
}
