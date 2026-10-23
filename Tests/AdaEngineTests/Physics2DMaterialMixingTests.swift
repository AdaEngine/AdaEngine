import AdaECS
@testable import AdaPhysics
import AdaTransform
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DMaterialMixingTests {
    @Test func policiesAreSymmetricAndUseDeterministicPrecedence() throws {
        let expected: [Float] = [0.4, 0.2, 0.4, 0.5, 0.16, 0.8]
        for (index, rule) in PhysicsMaterialCombineRule.allCases.enumerated() {
            var policy = PhysicsMaterialMixing()
            policy.friction = rule; policy.restitution = rule; policy.identifier = 123
            let value = PhysicsMaterialMixing.combine(0.2, idA: policy.nativeID, 0.8, idB: 0, restitution: false)
            #expect(abs(value - expected[index]) < 0.00001)
            #expect(value == PhysicsMaterialMixing.combine(0.8, idA: 0, 0.2, idB: policy.nativeID, restitution: false))
        }
        var minimum = PhysicsMaterialMixing()
        minimum.friction = .minimum; minimum.priority = 10
        var maximum = PhysicsMaterialMixing()
        maximum.friction = .maximum
        #expect(Physics2D_Friction(0.2, minimum.nativeID, 0.8, maximum.nativeID) == 0.2)
        minimum.priority = 0
        #expect(Physics2D_Friction(0.2, minimum.nativeID, 0.8, maximum.nativeID) == 0.8)
        #expect(Physics2D_Restitution(0.2, 42, 0.8, 77) == 0.8)
        let material = try PhysicsMaterial.generate2D(mixing: minimum)
        #expect(try JSONDecoder().decode(PhysicsMaterial.self, from: JSONEncoder().encode(material)).mixing == minimum)
    }

    @Test func restitutionCallbackChangesActualBounce() async throws {
        var peaks: [Float] = []
        for rule in [PhysicsMaterialCombineRule.nativeDefault, .minimum] {
            let fixture = try await PhysicsJoint2DFixture()
            let physics = try #require(fixture.app.main.physicsWorld2D)
            physics.restitutionThreshold = 0.1
            let floorMaterial = try PhysicsMaterial.generate2D(friction: 0, restitution: 0.2)
            fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 20, height: 1)], material: floorMaterial); Transform(position: [0, -0.5, 0]) }
            var policy = PhysicsMaterialMixing()
            policy.restitution = rule
            let material = try PhysicsMaterial.generate2D(friction: 0, restitution: 0.8, mixing: policy)
            var body = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1)], mass: 1, material: material)
            body.linearVelocity = [0, -5]
            let entity = fixture.app.main.spawn { body; Transform(position: [0, 1, 0]) }
            await fixture.app.main.runScheduler(.physicsSync)
            var peak: Float = 0
            for _ in 0..<90 {
                physics.updateSimulation(1.0 / 60)
                peak = max(peak, entity.components[PhysicsBody2DComponent.self]?.linearVelocity.y ?? 0)
            }
            peaks.append(peak)
        }
        #expect(peaks[0] > 3 && peaks[1] > 0.5 && peaks[1] < 1.5)
    }

    @Test func frictionRulesRemainIndependentBetweenWorlds() async throws {
        var fixtures: [PhysicsJoint2DFixture] = []
        var boxes: [Entity] = []
        for rule in [PhysicsMaterialCombineRule.minimum, .maximum] {
            let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
            let floorMaterial = try PhysicsMaterial.generate2D(friction: 0.1)
            fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 100, height: 1)], material: floorMaterial); Transform(position: [0, -0.5, 0]) }
            var policy = PhysicsMaterialMixing()
            policy.friction = rule; policy.priority = 20
            let material = try PhysicsMaterial.generate2D(friction: 0.9, mixing: policy)
            var body = PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1, material: material)
            body.fixedRotation = true; body.linearVelocity = [5, 0]
            boxes.append(fixture.app.main.spawn { body; Transform(position: [0, 0.5, 0]) })
            await fixture.app.main.runScheduler(.physicsSync)
            fixtures.append(fixture)
        }
        for _ in 0..<60 { for fixture in fixtures { try fixture.step(1) } }
        #expect(try #require(boxes[0].components[PhysicsBody2DComponent.self]).linearVelocity.x > 3)
        #expect(abs(try #require(boxes[1].components[PhysicsBody2DComponent.self]).linearVelocity.x) < 1)
    }
}
