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
    
    let gameLoop: GameLoop
    
    
    // MARK: Private
    
    private init() {
        self.gameLoop = GameLoop()
        self.gameLoop.makeCurrent()
    }
    
    // MARK: - Internal Methods
    
    // MARK: - Public Methods
    
}
