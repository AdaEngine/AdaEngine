//
//  PhysicsJoint2DComponent.swift
//  
//
//  Created by v.prusakov on 7/18/22.
//

@_implementationOnly import AdaBox2d
import Math

public final class PhysicsJoint2DDescriptor: Codable {
    
    let joint: Joint
    
    enum Joint: Codable {
        case rope(Entity.ID, Entity.ID, Vector2, Vector2)
        case revolute(Entity.ID)
    }
    
    internal init(joint: Joint) {
        self.joint = joint
    }
    
    public static func rope(entityA: Entity, entityB: Entity) -> PhysicsJoint2DDescriptor {
        return PhysicsJoint2DDescriptor(joint: .rope(entityA.id, entityB.id, .zero, .zero))
    }
    
    public static func revolute(entityA: Entity) -> PhysicsJoint2DDescriptor {
        return PhysicsJoint2DDescriptor(joint: .revolute(entityA.id))
    }
}

@Component
public struct PhysicsJoint2DComponent {
    let jointDescriptor: PhysicsJoint2DDescriptor
    
    var runtimeJoint: OpaquePointer?
    
    public init(joint: PhysicsJoint2DDescriptor) {
        self.jointDescriptor = joint
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.jointDescriptor = try container.decode(PhysicsJoint2DDescriptor.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.jointDescriptor)
    }
}
