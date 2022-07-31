//
//  PhysicsJoint2DComponent.swift
//  
//
//  Created by v.prusakov on 7/18/22.
//

import box2d
import Math

public final class PhysicsJoint2DDescriptor {
    
    let joint: Joint
    
    enum Joint {
        case rope(Entity, Entity, Vector2, Vector2)
        case revolute(Entity)
    }
    
    internal init(joint: Joint) {
        self.joint = joint
    }
    
    public static func rope(entityA: Entity, entityB: Entity) -> PhysicsJoint2DDescriptor {
        return PhysicsJoint2DDescriptor(joint: .rope(entityA, entityB, .zero, .zero))
    }
    
    public static func revolute(entityA: Entity) -> PhysicsJoint2DDescriptor {
        return PhysicsJoint2DDescriptor(joint: .revolute(entityA))
    }
}

public struct PhysicsJoint2DComponent: Component {
    let jointDescriptor: PhysicsJoint2DDescriptor
    
    var runtimeJoint: b2Joint?
    
    public init(joint: PhysicsJoint2DDescriptor) {
        self.jointDescriptor = joint
    }
}
