//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

import Physics

public struct PhysicsBody2DComponent: Component {
    let type: BodyType
}

public struct CollisionComponent: Component {
    
}

class PhysicsUpdateSystem: System {
    
    private var physicsFrame: Int = 0
    private var time: TimeInterval = 0
    // TODO: Should be modified
    private var physicsTicksPerSecond: Float = 60
    
    required init(scene: Scene) {
        
    }
    
    func update(context: UpdateContext) {
        let physicsStep = 1 / physicsTicksPerSecond
        
    }
}
