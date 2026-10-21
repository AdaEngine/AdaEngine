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
    public let breakSettings: JointBreak2DSettings

    enum Joint: Codable, Sendable {
        case rope(Entity.ID, Entity.ID, Vector2, Vector2)
        case revolute(Entity.ID)
        case distance(Entity.ID, Entity.ID, DistanceJoint2DSettings)
        case hinge(Entity.ID, Entity.ID, RevoluteJoint2DSettings)
        case worldHinge(Entity.ID, Vector2, RevoluteJoint2DSettings)
        case prismatic(Entity.ID, Entity.ID, PrismaticJoint2DSettings)
        case weld(Entity.ID, Entity.ID, WeldJoint2DSettings)
        case filter(Entity.ID, Entity.ID)
        case wheel(Entity.ID, Entity.ID, WheelJoint2DSettings)
        case motor(Entity.ID, Entity.ID, MotorJoint2DSettings)
    }

    internal init(joint: Joint, breakSettings: JointBreak2DSettings = .init()) {
        self.joint = joint
        self.breakSettings = breakSettings
    }

    func replacingJoint(_ value: Joint) -> PhysicsJoint2DDescriptor { PhysicsJoint2DDescriptor(joint: value, breakSettings: breakSettings) }

    private enum CodingKeys: CodingKey { case joint, breakSettings }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        joint = try values.decode(Joint.self, forKey: .joint)
        breakSettings = try values.decodeIfPresent(JointBreak2DSettings.self, forKey: .breakSettings) ?? .init()
        try breakSettings.validate()
        if case let .distance(_, _, settings) = joint { try settings.validate() }
        if case let .hinge(_, _, settings) = joint { try settings.validate() }
        if case let .prismatic(_, _, settings) = joint { try settings.validate() }
        if case let .weld(_, _, settings) = joint { try settings.validate() }
        if case let .wheel(_, _, settings) = joint { try settings.validate() }
        if case let .motor(_, _, settings) = joint { try settings.validate() }
        if case let .worldHinge(_, anchor, settings) = joint {
            try settings.validate()
            guard JointFrame2D(position: anchor).isValid else { throw PhysicsJoint2DError.invalidSettings }
        }
        if case let .rope(_, _, a, b) = joint {
            guard JointFrame2D(position: a).isValid, JointFrame2D(position: b).isValid else { throw PhysicsJoint2DError.invalidSettings }
        }
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
public struct PhysicsJoint2DComponent: Codable, Sendable {
    /// Replace the immutable descriptor to reconnect with new settings on the next physics sync.
    public var jointDescriptor: PhysicsJoint2DDescriptor
    public internal(set) var jointError: PhysicsJoint2DError?
    var runtimeJoint: RuntimeJoint2D?

    @MainActor public var isConnected: Bool { runtimeJoint?.isConnected ?? false }

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
