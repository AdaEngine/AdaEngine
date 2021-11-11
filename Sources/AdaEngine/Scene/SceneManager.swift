//
//  SceneManager.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class SceneManager {
    public static let shared = SceneManager()
    
    public var currentScene: Scene? {
        didSet {
            if let scene = self.currentScene {
                if CameraManager.shared.currentCamera == nil {
                    CameraManager.shared.setCurrentCamera(scene.defaultCamera)
                }
            }
        }
    }
    
    // MARK: - Private
    
    private init() {}
    
    func update(_ deltaTime: TimeInterval) {
        self.currentScene?.update(deltaTime)
    }
    
    // MARK: - Public Methods
    
    public func presentScene(_ scene: Scene) {
        self.currentScene = scene
    }
    
}
