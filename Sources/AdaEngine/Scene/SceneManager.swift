//
//  SceneManager.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class SceneManager {
    public static let shared = SceneManager()
    
    public var currentScene: Scene?
    
    // MARK: - Private
    
    private init() {}
    
    func update(_ deltaTime: TimeInterval) {
        self.currentScene?.update(deltaTime)
    }
    
    // MARK: - Public Methods
    
    public func presentScene(_ scene: Scene) {
        scene.sceneManager = self
        self.currentScene = scene
    }
    
}
