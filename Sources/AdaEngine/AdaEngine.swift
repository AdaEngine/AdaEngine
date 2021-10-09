//
//  AdaEngine.swift
//
//
//  Created by v.prusakov on 8/14/21.
//

import Foundation

#if METAL
import MetalKit
#else
import Vulkan
#endif

struct Time {
    var deltaTime: Double = 0
    var fixedTime: Double = 0
}

final public class Engine {
    
    public static let shared: Engine = Engine()
    
    private init() {
        
    }
    
}
