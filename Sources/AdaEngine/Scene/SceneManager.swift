//
//  SceneManager.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class SceneManager {
    
    public var currentScene: Scene?
    
    /// View where all renders happend
    public internal(set) weak var sceneView: SceneView?
    
    // MARK: - Private
    
    private weak var window: Window?
    
    internal init() { }
    
    func update(_ deltaTime: TimeInterval) {
        if self.currentScene?.isReady == false {
            self.currentScene?.ready()
        }
        
        self.currentScene?.update(deltaTime)
    }
    
    func setViewport(_ viewport: Viewport) {
        self.currentScene?.viewport = viewport
    }
    
    func setWindow(_ window: Window?) {
        self.currentScene?.window = window
        self.window = window
    }
    
    // MARK: - Public Methods
    
    public func presentScene(_ scene: Scene) {
        scene.sceneManager = self
        scene.window = self.window
        scene.viewport = self.sceneView?.viewport ?? Viewport()
        self.currentScene = scene
    }
    
}
