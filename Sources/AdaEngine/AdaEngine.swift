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
    
    // MARK: Private
    
    private var lastUpdate: Double = 0
    
    private init() { }
    
    // MARK: - Internal Methods
    
    func calculateDeltaTime() {
        let now = Time.absolute
        Time.deltaTime = max(0, now - self.lastUpdate)
        self.lastUpdate = now
    }
}
