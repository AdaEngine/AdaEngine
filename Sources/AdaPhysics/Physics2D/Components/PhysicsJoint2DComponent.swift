//
//  PhysicsJoint2DComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/18/22.
//

import AdaECS
import Math

public final class PhysicsJoint2DDescriptor: Codable, Sendable {
    
    let joint: Joint
    
    enum Joint: Codable, Sendable {
        case rope(Entity.ID, Entity.ID, Vector2, Vector2)
        case revolute(Entity.ID)
    }
    
    internal init(joint: Joint) {
        self.joint = joint
    }

    @MainActor
    public static func rope(entityA: Entity, entityB: Entity) -> PhysicsJoint2DDescriptor {
        return PhysicsJoint2DDescriptor(joint: .rope(entityA.id, entityB.id, .zero, .zero))
    }

    @MainActor
    public static func revolute(entityA: Entity) -> PhysicsJoint2DDescriptor {
        return PhysicsJoint2DDescriptor(joint: .revolute(entityA.id))
    }
}

@Component
@unsafe
public struct PhysicsJoint2DComponent: @unchecked Sendable {
    let jointDescriptor: PhysicsJoint2DDescriptor
    
    var runtimeJoint: OpaquePointer?
    
    public init(joint: PhysicsJoint2DDescriptor) {
        unsafe self.jointDescriptor = joint
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        unsafe self.jointDescriptor = try container.decode(PhysicsJoint2DDescriptor.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        unsafe try container.encode(self.jointDescriptor)
    }
}
