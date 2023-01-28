//
//  SceneManager.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class SceneManager {
    
    public var currentScene: Scene?
    
    weak var viewport: Viewport? {
        didSet {
            self.currentScene?.viewport = self.viewport
        }
    }
    
    // MARK: - Private
    
    internal init() { }
    
    func update(_ deltaTime: TimeInterval) {
        if self.currentScene?.isReady == false {
            self.currentScene?.ready()
        }
        
        self.currentScene?.update(deltaTime)
    }
    
    // MARK: - Public Methods
    
    public func presentScene(_ scene: Scene) {
        scene.sceneManager = self
        scene.viewport = self.viewport
        self.currentScene = scene
    }
    
}
