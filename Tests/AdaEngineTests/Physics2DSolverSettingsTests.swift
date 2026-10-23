import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Foundation
import Math
import Testing

private final class SolverDelegate2D: PhysicsWorld2DDelegate {
    func physicsWorldOnPreSolve(_ world: PhysicsWorld2D, entityA: Entity, entityB: Entity, manifold: Manifold2D?) -> Bool { true }
    func physicsWorldOnCustomFilterCalled(_ world: PhysicsWorld2D, entityA: Entity, entityB: Entity) -> Bool { true }
}

@MainActor
@Suite(.serialized)
struct Physics2DSolverSettingsTests {
    @Test func settingsReachNativeSolverAndCapActualVelocity() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        var settings = physics.solverSettings
        settings.substepIterations = 8; settings.contactHertz = 45; settings.contactDampingRatio = 0.8
        settings.contactPushSpeed = 2; settings.restitutionIterations = 8; settings.isRestitutionPropagationEnabled = true
        settings.restitutionThreshold = 0.4; settings.hitEventThreshold = 0.2; settings.maximumLinearSpeed = 3
        settings.contactRecycleDistance = 0.2; settings.isSleepEnabled = false
        settings.isContinuousEnabled = false; settings.isWarmStartingEnabled = false
        try physics.configureSolver(settings)
        #expect(physics.solverSettings == settings)
        #expect(b2World_GetRestitutionIterations(physics.worldId) == 8 && b2World_IsRestitutionPropagationEnabled(physics.worldId))
        let entity = fixture.body()
        entity.components[PhysicsBody2DComponent.self]?.linearVelocity = [100, 0]
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(1)
        #expect(try #require(entity.components[PhysicsBody2DComponent.self]).linearVelocity.x <= 3.001)
        let before = physics.solverSettings
        settings.contactHertz = .nan
        #expect(throws: PhysicsSolver2DError.invalidSettings) { try physics.configureSolver(settings) }
        #expect(physics.solverSettings == before)
        let step = physics.simulationStep
        physics.substepIterations = 0
        physics.updateSimulation(1.0 / 60)
        #expect(physics.simulationStep == step)
    }

    @Test func contactPushTuningChangesRealOverlapRecovery() async throws {
        var positions: [Float] = []
        for speed in [Float(0), 3] {
            let fixture = try await PhysicsJoint2DFixture()
            let physics = try #require(fixture.app.main.physicsWorld2D)
            var settings = physics.solverSettings
            settings.contactHertz = 30; settings.contactDampingRatio = 1; settings.contactPushSpeed = speed
            try physics.configureSolver(settings)
            _ = fixture.body(mode: .static)
            let body = fixture.body(at: [0.2, 0])
            await fixture.app.main.runScheduler(.physicsSync)
            try fixture.step(60)
            positions.append(try #require(body.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition().x)
        }
        #expect(positions[1] > positions[0] + 0.1)
    }

    @Test func recyclingOverridesAndWorldSerializationPreserveAuthoredSettings() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        var settings = physics.solverSettings
        settings.contactRecycleDistance = 0.2; settings.restitutionIterations = 10
        let delegate = SolverDelegate2D()
        physics.delegate = delegate
        try physics.configureSolver(settings)
        #expect(physics.effectiveContactRecycleDistance == 0 && physics.solverSettings.contactRecycleDistance == 0.2)
        physics.delegate = nil
        #expect(physics.effectiveContactRecycleDistance == 0.2)
        withExtendedLifetime(delegate) {}
        var controller = CharacterController2DComponent()
        controller.mode = .dynamic
        let character = fixture.app.main.spawn { controller; Transform() }
        await fixture.app.main.runScheduler(.physicsSync)
        let id = try #require(character.components[CharacterController2DComponent.self]?.runtime?.body).bodyId
        #expect(!b2Body_IsContactRecyclingEnabled(id))
        try physics.configureSolver(settings)
        #expect(!b2Body_IsContactRecyclingEnabled(id))
        let data = try JSONEncoder().encode(physics)
        #expect(try JSONDecoder().decode(PhysicsWorld2D.self, from: data).solverSettings == settings)
        let legacy = Data(#"{"gravity":{"x":0,"y":-9.81},"substepIterations":2}"#.utf8)
        #expect(try JSONDecoder().decode(PhysicsWorld2D.self, from: legacy).substepIterations == 2)
        settings.restitutionIterations = Int(B2_MAX_RESTITUTION_ITERATIONS) + 1
        #expect(throws: PhysicsSolver2DError.invalidSettings) { try physics.configureSolver(settings) }
    }
}
