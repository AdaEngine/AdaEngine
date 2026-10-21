//
//  CollisionEvents.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

import AdaECS
import AdaUtils
import Math

/// Events associated with collisions.
public enum CollisionEvents {
    /// An event raised when two objects collide.
    public struct Began: Event {
        /// The first entity involved in the collision.
        public let entityA: Entity

        /// The second entity involved in the collision.
        public let entityB: Entity

        /// The estimated strength of the impact.
        public let impulse: Float

        /// True for a sensor overlap; `entityA` is the sensor and the impulse is zero.
        public let isSensor: Bool

        public init(entityA: Entity, entityB: Entity, impulse: Float, isSensor: Bool = false) {
            self.entityA = entityA
            self.entityB = entityB
            self.impulse = impulse
            self.isSensor = isSensor
        }
    }

    /// An event raised when two objects, previously in contact, separate.
    public struct Ended: Event {
        /// The first entity involved in the collision.
        public let entityA: Entity

        /// The second entity involved in the collision.
        public let entityB: Entity

        /// True when a sensor overlap ends. `entityA` is the sensor.
        public let isSensor: Bool

        public init(entityA: Entity, entityB: Entity, isSensor: Bool = false) {
            self.entityA = entityA
            self.entityB = entityB
            self.isSensor = isSensor
        }
    }

    /// A solid-body impact exceeding ``PhysicsWorld2D/hitEventThreshold``.
    public struct Hit: Event {
        public let entityA: Entity
        public let entityB: Entity
        public let point: Vector2
        /// Exact global 2D hit point.
        public let globalPoint: PhysicsPosition2D
        /// Points from `entityA` toward `entityB`.
        public let normal: Vector2
        /// Positive relative approach speed in world units per second.
        public let approachSpeed: Float
        /// Sum of the contact's total normal impulses for this step.
        public let impulse: Float
    }
}
