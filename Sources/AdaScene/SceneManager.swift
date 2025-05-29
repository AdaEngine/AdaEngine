//
//  SceneManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/3/21.
//

import AdaUtils
import AdaUI

/// SceneManager used for scene managment on screen. Each scene has access to scene manager instance.
/// You can use scene manager for transition between scenes.
@MainActor
public class SceneManager {

    public private(set) var currentScene: Scene?
    
    /// View where all renders happend
    public internal(set) weak var sceneView: SceneView?
    
    // MARK: - Private
    
    internal init() { }
    
    /// Update current scene by delta time.
    func update(_ deltaTime: TimeInterval) async {
        guard let currentScene else {
            return
        }

        currentScene.readyIfNeeded()
        await currentScene.update(deltaTime)
    }
    
    /// Set window for scene manager.
    func setWindow(_ window: UIWindow?) {
        self.currentScene?.window = window
    }
    
    // MARK: - Public Methods
    
    /// Set new scene for presenting on screen.
    public func presentScene(_ scene: Scene) {
        guard let view = self.sceneView else {
            assertionFailure("Can't present scene without SceneView.")
            return
        }

        self.currentScene?.sceneWillMove(from: view)
        scene.sceneManager = self
        scene.window = view.window
        self.currentScene = scene
        scene.sceneDidMove(to: view)
    }
    
}
