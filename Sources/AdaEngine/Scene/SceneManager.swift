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
    let renderGraphExecutor = RenderGraphExecutor()
    
    // MARK: - Private
    
    private weak var window: Window?
    
    internal init() { }
    
    func update(_ deltaTime: TimeInterval) {
        guard let currentScene else {
            return
        }
        if currentScene.isReady == false {
            currentScene.ready()
        }
        
        currentScene.update(deltaTime)
        
        do {
            try self.renderGraphExecutor.execute(currentScene.sceneRenderGraph, in: currentScene)
        } catch {
            fatalError(error.localizedDescription)
        }
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
