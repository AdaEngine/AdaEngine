import AdaEngine

extension Physics2DDemoMain {
    static func validateAdvanced(_ app: AppWorlds, _ session: PhysicsDemoSession) async throws {
        let state = session.advanced
        guard state.pointCount > 0, let air = state.air, let projectile = state.projectile else { throw Failure.advanced }
        state.windMode = 1; state.dirty = true
        await advance(app, steps: 30)
        let speed = air.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 0
        guard speed > 0.2 else { throw Failure.advanced }
        state.windMode = 2; state.dirty = true
        await advance(app, steps: 20)
        guard (air.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 0) < speed else { throw Failure.advanced }
        state.locked = true; state.dirty = true
        await advance(app, steps: 2)
        guard abs(air.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 1) < 0.01 else { throw Failure.advanced }
        state.locked = false; state.damping = true; state.softSolver = true
        state.reverseBelt = true; state.rolling = false; state.lowGrip = true; state.dirty = true
        await advance(app, steps: 2)
        guard app.main.physicsWorld2D?.solverSettings.restitutionIterations == 8,
            state.belt?.components[Collision2DComponent.self]?.material.surfaceSpeed == -1.8,
            state.circle?.components[PhysicsBody2DComponent.self]?.material.mixing.friction == .minimum else { throw Failure.advanced }
        air.components[PhysicsBody2DComponent.self]?.setAwake(true)
        state.sleepRequested = true
        await advance(app, steps: 1)
        guard air.components[PhysicsBody2DComponent.self]?.isAwake == false else { throw Failure.advanced }
        state.sleepRequested = true; state.bullet = false; state.dirty = true; state.refireRequested = true
        await advance(app, steps: 30)
        guard (projectile.components[PhysicsBody2DComponent.self]?.worldCenter.x ?? -1) > 0 else { throw Failure.advanced }
        state.bullet = true; state.dirty = true; state.refireRequested = true
        await advance(app, steps: 30)
        guard (projectile.components[PhysicsBody2DComponent.self]?.worldCenter.x ?? 1) < 0, state.hitPoints > 0 else { throw Failure.advanced }
        report("PASS: advanced · wind / drag / locks / sleep / materials / CCD / contacts / solver")
    }

    static func verifyAdvanced(to directory: String, tap: (String) throws -> Void) async throws {
        try tap("physics-demo.advanced")
        let source = try await waitForSource("Physics2D Advanced")
        guard let session = source.world?.getResource(PhysicsDemoSession.self), let air = session.advanced.air else { throw Failure.advanced }
        let state = session.advanced
        try tap("physics-demo.advanced-wind")
        _ = try await nextFrames(source, count: 30)
        let speed = air.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 0
        guard speed > 0.2 else { throw Failure.advanced }
        try tap("physics-demo.advanced-wind")
        _ = try await nextFrames(source, count: 20)
        guard (air.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 0) < speed else { throw Failure.advanced }
        try tap("physics-demo.advanced-lock")
        _ = try await nextFrames(source)
        guard air.components[PhysicsBody2DComponent.self]?.motion.lockTranslationX == true,
            abs(air.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 1) < 0.01 else { throw Failure.advanced }
        try tap("physics-demo.advanced-lock")
        _ = try await nextFrames(source)
        if air.components[PhysicsBody2DComponent.self]?.isAwake == false { try tap("physics-demo.advanced-sleep"); _ = try await nextFrames(source) }
        try tap("physics-demo.advanced-sleep")
        _ = try await nextFrames(source)
        guard air.components[PhysicsBody2DComponent.self]?.isAwake == false else { throw Failure.advanced }
        try tap("physics-demo.advanced-sleep")
        try tap("physics-demo.advanced-damping")
        try tap("physics-demo.advanced-belt")
        try tap("physics-demo.advanced-rolling")
        try tap("physics-demo.advanced-grip")
        try tap("physics-demo.advanced-solver")
        _ = try await nextFrames(source)
        guard source.world?.physicsWorld2D?.solverSettings.contactHertz == 8,
            air.components[PhysicsBody2DComponent.self]?.dynamics.linearDamping == 2,
            state.circle?.components[PhysicsBody2DComponent.self]?.material.rollingResistance == 0,
            state.belt?.components[Collision2DComponent.self]?.material.surfaceSpeed == -1.8 else { throw Failure.advanced }
        try tap("physics-demo.advanced-bullet")
        _ = try await nextFrames(source, count: 30)
        guard (state.projectile?.components[PhysicsBody2DComponent.self]?.worldCenter.x ?? -1) > 0 else { throw Failure.advanced }
        try tap("physics-demo.advanced-bullet")
        let frame = try await nextFrames(source, count: 30)
        guard (state.projectile?.components[PhysicsBody2DComponent.self]?.worldCenter.x ?? 1) < 0,
            state.pointCount > 0, state.hitPoints > 0 else { throw Failure.advanced }
        try write(frame.image, to: directory + "/advanced-physics.png")
        try tap("physics-demo.advanced-reset")
        _ = try await nextFrames(source)
        report("PASS: native advanced · wind / drag / locks / sleep / materials / CCD / contact points / solver controls")
    }
}
