//
//  SceneManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/3/21.
//

/// SceneManager used for scene managment on screen. Each scene has access to scene manager instance.
/// You can use scene manager for transition between scenes.
@MainActor
public class SceneManager {
    
    public private(set) var currentScene: Scene?
    
    /// View where all renders happend
    public internal(set) weak var sceneView: SceneView?
    
    // MARK: - Private
    
    private weak var window: Window?
    
    internal init() { }
    
    /// Update current scene by delta time.
    func update(_ deltaTime: TimeInterval) async {
        guard let currentScene else {
            return
        }

        await currentScene.readyIfNeeded()
        await currentScene.update(deltaTime)
    }
    
    /// Set viewport for current scene.
    func setViewport(_ viewport: Viewport) {
        Task { @ECSActor in
            await self.currentScene?.viewport = viewport
        }
    }
    
    /// Set window for scene manager.
    func setWindow(_ window: Window?) {
        Task { @ECSActor in
            await self.currentScene?.window = window

            await MainActor.run {
                self.window = window
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Set new scene for presenting on screen.
    public func presentScene(_ scene: Scene) {
        Task { @ECSActor in
            scene.sceneManager = self
            scene.window = await self.window
            scene.viewport = await self.sceneView?.viewport ?? Viewport()

            await MainActor.run {
                self.currentScene = scene
            }
        }
    }
    
}
