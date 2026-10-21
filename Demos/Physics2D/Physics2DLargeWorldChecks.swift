import AdaEngine

extension Physics2DDemoMain {
    static func validateLargeWorld(_ app: AppWorlds, _ session: PhysicsDemoSession) async throws {
        let state = session.largeWorld
        guard let physics = app.main.physicsWorld2D, let player = session.character, let hit = state.hit,
            state.pointCount > 0, state.hinge?.components[PhysicsJoint2DComponent.self]?.isConnected == true else { throw Failure.largeWorld }
        let before = hit.x
        state.nudgeRequested = true
        await advance(app, steps: 2)
        guard let nudged = state.hit, nudged.x - before > 0.0009, nudged.x - before < 0.0011 else { throw Failure.largeWorld }
        let contact = state.contactID
        state.shifted = true
        await advance(app, steps: 2)
        guard physics.coordinateOrigin == state.base.offset(by: [1000, -500]), state.hit == nudged,
            state.contactID == contact, player.components[CharacterController2DComponent.self]?.isGrounded == true else { throw Failure.largeWorld }
        let start = player.components[PhysicsPosition2DComponent.self]?.position.x ?? 0
        state.direction = 1
        await advance(app, steps: 30)
        state.direction = 0
        await advance(app, steps: 15)
        guard (player.components[PhysicsPosition2DComponent.self]?.position.x ?? 0) > start + 0.1 else { throw Failure.largeWorld }
        state.jumpRequested = true
        await advance(app, steps: 1)
        guard player.components[CharacterController2DComponent.self]?.isGrounded == false else { throw Failure.largeWorld }
        await advance(app, steps: 90)
        state.mode = .dynamic
        await advance(app, steps: 60)
        guard player.components[CharacterController2DComponent.self]?.isGrounded == true else { throw Failure.largeWorld }
        state.jumpRequested = true
        await advance(app, steps: 1)
        guard player.components[CharacterController2DComponent.self]?.isGrounded == false else { throw Failure.largeWorld }
        report("PASS: large worlds · exact queries / 1 mm nudge / origin shift / stable contacts and hinge / both character modes")
    }

    static func verifyLargeWorld(to directory: String, tap: (String) throws -> Void) async throws {
        let oldAdvanced = SceneViewFrameRegistry.latest(label: "Physics2D Advanced")
        try tap("physics-demo.large-world")
        let source = try await waitForSource("Physics2D Large worlds")
        guard let session = source.world?.getResource(PhysicsDemoSession.self), let physics = source.world?.physicsWorld2D,
            let player = session.character else { throw Failure.largeWorld }
        let state = session.largeWorld
        try await waitForGround(source, session)
        guard let hit = state.hit, state.pointCount > 0 else { throw Failure.largeWorld }
        let contact = state.contactID
        try tap("physics-demo.large-nudge")
        _ = try await nextFrames(source)
        guard let nudged = state.hit, nudged.x - hit.x > 0.0009, nudged.x - hit.x < 0.0011 else { throw Failure.largeWorld }
        let before = try await nextFrames(source)
        try write(before.image, to: directory + "/large-world-before.png")
        try tap("physics-demo.large-origin")
        let shifted = try await nextFrames(source)
        guard physics.coordinateOrigin == state.base.offset(by: [1000, -500]), state.hit == nudged,
            state.contactID == contact, state.hinge?.components[PhysicsJoint2DComponent.self]?.isConnected == true else { throw Failure.largeWorld }
        try write(shifted.image, to: directory + "/large-world-shifted.png")
        let start = player.components[PhysicsPosition2DComponent.self]?.position.x ?? 0
        try tap("physics-demo.large-right")
        _ = try await nextFrames(source, count: 30)
        try tap("physics-demo.large-stop")
        _ = try await nextFrames(source, count: 15)
        guard (player.components[PhysicsPosition2DComponent.self]?.position.x ?? 0) > start + 0.1 else { throw Failure.largeWorld }
        try tap("physics-demo.large-jump")
        try await waitForJump(source, session)
        try await waitForGround(source, session)
        try tap("physics-demo.large-mode")
        _ = try await nextFrames(source)
        try await waitForGround(source, session)
        guard hasCharacterCollider(source, session) else { throw Failure.largeWorld }
        let dynamic = try await nextFrames(source)
        try write(dynamic.image, to: directory + "/large-world-dynamic.png")
        try tap("physics-demo.large-jump")
        try await waitForJump(source, session)
        try await waitForGround(source, session)
        try tap("physics-demo.large-mode")
        _ = try await nextFrames(source)
        guard !hasCharacterCollider(source, session) else { throw Failure.largeWorld }
        try tap("physics-demo.advanced")
        _ = try await waitForSource("Physics2D Advanced", excluding: oldAdvanced)
        try tap("physics-demo.large-world")
        let rebuilt = try await waitForSource("Physics2D Large worlds", excluding: source)
        guard let fresh = rebuilt.world?.getResource(PhysicsDemoSession.self), fresh.character !== player,
            let freshPhysics = rebuilt.world?.physicsWorld2D, freshPhysics.coordinateOrigin == state.base else { throw Failure.largeWorld }
        if let contact { guard !freshPhysics.isValid(contact) else { throw Failure.largeWorld } }
        report("PASS: native large worlds · exact query / millimeter nudge / camera origin shift / contacts / both character jumps / re-entry")
    }
}
