import box2d

public enum PhysicsSolver2DError: Error, Equatable, Sendable { case invalidSettings }

/// Authored world solver/stepping configuration. Defaults come from the bundled Box2D version.
public struct PhysicsSolver2DSettings: Codable, Equatable, Sendable {
    public var substepIterations: Int
    public var contactHertz: Float
    public var contactDampingRatio: Float
    public var contactPushSpeed: Float
    public var restitutionThreshold: Float
    public var restitutionIterations: Int
    /// Experimental native propagation; potentially expensive.
    public var isRestitutionPropagationEnabled: Bool
    public var hitEventThreshold: Float
    public var maximumLinearSpeed: Float
    /// Authored distance; a delegate temporarily forces the effective value to zero.
    public var contactRecycleDistance: Float
    public var isSleepEnabled: Bool
    public var isContinuousEnabled: Bool
    public var isWarmStartingEnabled: Bool

    public init() {
        let definition = unsafe b2DefaultWorldDef()
        substepIterations = 4
        contactHertz = unsafe definition.contactHertz
        contactDampingRatio = unsafe definition.contactDampingRatio
        contactPushSpeed = unsafe definition.contactSpeed
        restitutionThreshold = unsafe definition.restitutionThreshold
        restitutionIterations = unsafe Int(definition.restitutionIterations)
        isRestitutionPropagationEnabled = unsafe definition.enableRestitutionPropagation
        hitEventThreshold = unsafe definition.hitEventThreshold
        maximumLinearSpeed = unsafe definition.maximumLinearSpeed
        contactRecycleDistance = 10 * (0.005 * b2GetLengthUnitsPerMeter())
        isSleepEnabled = unsafe definition.enableSleep
        isContinuousEnabled = unsafe definition.enableContinuous
        isWarmStartingEnabled = true
    }

    func validate() throws(PhysicsSolver2DError) {
        let nonnegative = [contactHertz, contactDampingRatio, contactPushSpeed, restitutionThreshold, hitEventThreshold, contactRecycleDistance]
        guard nonnegative.allSatisfy({ $0.isFinite && $0 >= 0 }), maximumLinearSpeed.isFinite, maximumLinearSpeed > 0,
            substepIterations > 0, substepIterations <= Int(Int32.max),
            restitutionIterations >= 0, restitutionIterations <= Int(B2_MAX_RESTITUTION_ITERATIONS) else { throw .invalidSettings }
    }
}

extension PhysicsWorld2D {
    /// Reads current native values and retains the authored recycling value even while a delegate overrides it.
    public var solverSettings: PhysicsSolver2DSettings {
        var settings = PhysicsSolver2DSettings()
        settings.substepIterations = substepIterations
        var hertz: Float = 0
        var damping: Float = 0
        var speed: Float = 0
        unsafe b2World_GetContactTuning(worldId, &hertz, &damping, &speed)
        settings.contactHertz = hertz; settings.contactDampingRatio = damping; settings.contactPushSpeed = speed
        settings.restitutionThreshold = restitutionThreshold
        settings.restitutionIterations = Int(b2World_GetRestitutionIterations(worldId))
        settings.isRestitutionPropagationEnabled = b2World_IsRestitutionPropagationEnabled(worldId)
        settings.hitEventThreshold = hitEventThreshold
        settings.maximumLinearSpeed = b2World_GetMaxLinearSpeed(worldId)
        settings.contactRecycleDistance = authoredContactRecycleDistance
        settings.isSleepEnabled = isSleepEnabled
        settings.isContinuousEnabled = isContinuousEnabled
        settings.isWarmStartingEnabled = isWarmStartingEnabled
        return settings
    }

    public var effectiveContactRecycleDistance: Float { b2World_GetContactRecycleDistance(worldId) }

    /// Atomic validation before mutation; call between native simulation steps on the main actor.
    @MainActor
    public func configureSolver(_ settings: PhysicsSolver2DSettings) throws(PhysicsSolver2DError) {
        try settings.validate()
        applySolver(settings)
    }

    // Also used during unpublished Codable initialization, before any body or delegate exists.
    func applySolver(_ settings: PhysicsSolver2DSettings) {
        substepIterations = settings.substepIterations
        b2World_SetContactTuning(worldId, settings.contactHertz, settings.contactDampingRatio, settings.contactPushSpeed)
        b2World_SetRestitutionThreshold(worldId, settings.restitutionThreshold)
        b2World_SetRestitutionIterations(worldId, Int32(settings.restitutionIterations))
        b2World_EnableRestitutionPropagation(worldId, settings.isRestitutionPropagationEnabled)
        b2World_SetHitEventThreshold(worldId, settings.hitEventThreshold)
        b2World_SetMaxLinearSpeed(worldId, settings.maximumLinearSpeed)
        authoredContactRecycleDistance = settings.contactRecycleDistance
        b2World_SetContactRecycleDistance(worldId, delegate == nil ? authoredContactRecycleDistance : 0)
        b2World_EnableSleeping(worldId, settings.isSleepEnabled)
        b2World_EnableContinuous(worldId, settings.isContinuousEnabled)
        b2World_EnableWarmStarting(worldId, settings.isWarmStartingEnabled)
    }
}
