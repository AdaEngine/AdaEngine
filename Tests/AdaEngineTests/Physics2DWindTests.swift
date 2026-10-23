import AdaECS
@testable import AdaPhysics
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DWindTests {
    @Test func fixedStepWindAcceleratesAndStillAirDragDecelerates() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        fixture.app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        let entity = fixture.app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1)], mass: 1)
            PhysicsWind2DComponent(.init(velocity: [8, 0]))
            Transform()
        }
        await fixture.app.main.runScheduler(.physicsSync)
        for _ in 0..<60 { await fixture.app.main.runScheduler(.physicsStep) }
        let speed = try #require(entity.components[PhysicsBody2DComponent.self]).linearVelocity.x
        #expect(speed > 4 && speed < 8)
        entity.components[PhysicsWind2DComponent.self]?.settings.velocity = .zero
        for _ in 0..<60 { await fixture.app.main.runScheduler(.physicsStep) }
        let slowed = try #require(entity.components[PhysicsBody2DComponent.self]).linearVelocity.x
        #expect(slowed > 0 && slowed < speed * 0.5)
        #expect(entity.components[PhysicsBody2DComponent.self]?.dynamics.linearDamping == 0)
        entity.components[PhysicsWind2DComponent.self]?.settings.drag = -1
        await fixture.app.main.runScheduler(.physicsStep)
        #expect(entity.components[PhysicsWind2DComponent.self]?.lastError == .invalidSettings)
    }

    @Test func sensorPolicyAndSleepingAreExplicit() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let entity = fixture.app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1)], mass: 1, isTrigger: true)
            Transform()
        }
        await fixture.app.main.runScheduler(.physicsSync)
        let physics = try #require(fixture.app.main.physicsWorld2D)
        var body = try #require(entity.components[PhysicsBody2DComponent.self])
        var wind = PhysicsWind2D(velocity: [8, 0])
        #expect(try !body.applyWind(wind))
        physics.updateSimulation(1.0 / 60)
        #expect(body.linearVelocity == .zero)
        wind.includeSensors = true
        body.setAwake(false)
        #expect(try body.applyWind(wind))
        physics.updateSimulation(1.0 / 60)
        #expect(!body.isAwake && body.linearVelocity == .zero)
        wind.wakeSleepingBodies = true
        #expect(try body.applyWind(wind))
        physics.updateSimulation(1.0 / 60)
        #expect(body.isAwake && body.linearVelocity.x > 0)
        let kinematic = fixture.body(at: [10, 0], mode: .kinematic)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(try #require(kinematic.components[PhysicsBody2DComponent.self]).applyWind(wind) == false)
    }

    @Test func windRoundTripAndInvalidInputs() throws {
        let wind = PhysicsWind2D(velocity: [3, 4], drag: 0.5, lift: -0.2, wakeSleepingBodies: true)
        let component = PhysicsWind2DComponent(wind)
        #expect(try JSONDecoder().decode(PhysicsWind2DComponent.self, from: JSONEncoder().encode(component)).settings == wind)
        var invalid = wind
        invalid.lift = .nan
        #expect(throws: PhysicsWind2DError.invalidSettings) { try invalid.validate() }
        invalid = wind; invalid.velocity = [.infinity, 0]
        #expect(throws: PhysicsWind2DError.invalidSettings) { try invalid.validate() }
    }
}
