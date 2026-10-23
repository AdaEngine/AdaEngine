import box2d
import Math

/// Axis constraints and sleep policy. initiallyAwake is applied only when the native body is created.
public struct PhysicsBody2DMotion: Codable, Equatable, Sendable {
    public var lockTranslationX: Bool = false
    public var lockTranslationY: Bool = false
    /// Combined with the legacy PhysicsBody2DComponent.fixedRotation using logical OR.
    public var lockRotation: Bool = false
    public var isSleepEnabled: Bool = true
    public var sleepThreshold: Float = 0.05
    public var initiallyAwake: Bool = true

    public init() {}
    func validate() throws(PhysicsBody2DSettingsError) {
        guard sleepThreshold.isFinite, sleepThreshold >= 0 else { throw .invalidMotion }
    }
    func locks(fixedRotation: Bool) -> b2MotionLocks {
        b2MotionLocks(linearX: lockTranslationX, linearY: lockTranslationY, angularZ: lockRotation || fixedRotation)
    }
    func apply(to definition: inout b2BodyDef, fixedRotation: Bool) {
        definition.motionLocks = locks(fixedRotation: fixedRotation)
        definition.enableSleep = isSleepEnabled
        definition.sleepThreshold = sleepThreshold
        definition.isAwake = initiallyAwake
    }
}

@MainActor
extension PhysicsBody2DComponent {
    /// Validates atomically. Retains body identity and authored mass while updating native locks/sleep policy.
    /// Changing initiallyAwake here does not override an existing body's observed awake state.
    public mutating func configureMotion(_ settings: PhysicsBody2DMotion) throws(PhysicsBody2DSettingsError) {
        try settings.validate()
        motion = settings
        runtimeBody?.applyMotion(settings, fixedRotation: fixedRotation, massProperties: massProperties)
    }

    public var isAwake: Bool {
        guard let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return motion.initiallyAwake
        }
        return b2Body_IsAwake(body.bodyId)
    }

    /// Explicit command; sleeping a native body can sleep its whole touching island.
    /// Before creation, sets the authored initial state. Native sleep transitions are otherwise left alone.
    public mutating func setAwake(_ awake: Bool) {
        if let body = runtimeBody, b2Body_IsValid(body.bodyId) {
            b2Body_SetAwake(body.bodyId, awake)
        } else { motion.initiallyAwake = awake }
    }
}

extension Body2D {
    func applyMotion(_ settings: PhysicsBody2DMotion, fixedRotation: Bool, massProperties: PhysicsMassProperties) {
        guard b2Body_IsValid(bodyId) else {
            return
        }
        let locks = settings.locks(fixedRotation: fixedRotation)
        let old = b2Body_GetMotionLocks(bodyId)
        if locks.linearX != old.linearX || locks.linearY != old.linearY || locks.angularZ != old.angularZ {
            let previous = b2Body_GetMassData(bodyId)
            b2Body_SetMotionLocks(bodyId, locks)
            // SetMotionLocks recomputes mass from shapes. Preserve the engine's authored dynamic mass policy.
            if b2Body_GetType(bodyId) == b2_dynamicBody {
                var mass = b2Body_GetMassData(bodyId)
                mass.mass = massProperties.mass
                mass.center = previous.center
                if locks.angularZ { mass.rotationalInertia = 0 } else if massProperties.inertia.z > 0 { mass.rotationalInertia = massProperties.inertia.z }
                b2Body_SetMassData(bodyId, mass)
            }
        }
        if b2Body_IsSleepingEnabled(bodyId) != settings.isSleepEnabled { b2Body_EnableSleeping(bodyId, settings.isSleepEnabled) }
        if b2Body_GetSleepThreshold(bodyId) != settings.sleepThreshold { b2Body_SetSleepThreshold(bodyId, settings.sleepThreshold) }
    }
}
