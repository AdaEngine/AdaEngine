@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DPrecisionTests {
    @Test func nativeABIAndNearbyDisplacements() throws {
        #expect(MemoryLayout<b2Pos>.size == 16)
        #expect(MemoryLayout<b2Vec2>.size == 8)
        let position = PhysicsPosition2D(x: 1_000_000_000.125, y: -1_000_000_000.25)
        #expect(position.displacement(from: .init(x: 1_000_000_000, y: -1_000_000_000)) == Vector2(0.125, -0.25))
        #expect(try JSONDecoder().decode(PhysicsPosition2D.self, from: JSONEncoder().encode(position)) == position)
    }

    @Test func preciseRayAndSmallMotionFarFromOrigin() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let entity = fixture.body()
        await fixture.app.main.runScheduler(.physicsSync)
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let component = try #require(entity.components[PhysicsBody2DComponent.self])
        let initial = PhysicsPosition2D(x: 1_000_000_000.125, y: 1_000_000_000.25)
        #expect(component.setGlobalPosition(initial))
        #expect(component.precisePosition == initial)
        let hit = try #require(physics.raycast(from: initial.offset(by: [-1, 0]), translation: [2, 0], query: .first).first)
        #expect(hit.entity === entity)
        #expect(abs(hit.point.x - (initial.x - 0.25)) < 0.00001)
        #expect(abs(hit.distance - 0.75) < 0.00001)
        component.runtimeBody?.setLinearVelocity([0.1, 0])
        physics.updateSimulation(1.0 / 60)
        let moved = try #require(component.precisePosition)
        #expect(moved.x > initial.x + 0.001)
        #expect(moved.x < initial.x + 0.002)
        #expect(!component.setGlobalPosition(.init(x: .nan, y: 0)))
        #expect(physics.raycast(from: initial, translation: .zero).isEmpty)
    }
}
