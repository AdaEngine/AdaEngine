//
//  AdaEngine.swift
//
//
//  Created by v.prusakov on 8/14/21.
//

#if METAL
import MetalKit
#else
import Vulkan
#endif

final public class Engine {
    
    public static let shared: Engine = Engine()
    
    let gameLoop = GameLoop()
    
    // MARK: Private
    
    private init() { }
    
    // MARK: - Internal Methods
    
    func run() {
        self.gameLoop.makeCurrent()
    }
    
    // MARK: - Public Methods
    
    public func setRootScene(_ scene: Scene) {
//        scene.viewportSize = RenderEngine.shared.renderBackend.viewportSize
        SceneManager.shared.presentScene(scene)
    }
}
