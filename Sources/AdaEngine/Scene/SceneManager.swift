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
            self.currentScene.flatMap { CameraManager.shared.setCurrentCamera($0.defaultCamera) }
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
