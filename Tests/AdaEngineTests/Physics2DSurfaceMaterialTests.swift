import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DSurfaceMaterialTests {
    @Test func conveyorMovesAndReversesWithoutRecreatingShapes() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let beltMaterial = try PhysicsMaterial.generate2D(surfaceSpeed: 3)
        let belt = fixture.app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 100, height: 1)], material: beltMaterial)
            Transform(position: [0, -0.5, 0])
        }
        let box = fixture.body(at: [0, 0.5])
        await fixture.app.main.runScheduler(.physicsSync)
        let body = try #require(box.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let floor = try #require(belt.components[Collision2DComponent.self]?.runtimeBody)
        let shape = try #require(floor.getShapes().first)
        let id = b2StoreShapeId(shape.nativeID)
        try fixture.step(120)
        #expect(body.getPosition().x > 1 && body.getLinearVelocity().x > 2)
        belt.components[Collision2DComponent.self]?.material = try PhysicsMaterial.generate2D(surfaceSpeed: -3)
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(120)
        #expect(body.getLinearVelocity().x < -2)
        #expect(b2StoreShapeId(try #require(floor.getShapes().first).nativeID) == id)
    }

    @Test func rollingResistanceSlowsARealRollingCircle() async throws {
        var speeds: [Float] = []
        for resistance in [Float(0), 0.3] {
            let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
            fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 100, height: 1)]); Transform(position: [0, -0.5, 0]) }
            var component = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1)], mass: 1, material: try .generate2D(rollingResistance: resistance))
            component.linearVelocity = [2, 0]; component.angularVelocity = -4
            let entity = fixture.app.main.spawn { component; Transform(position: [0, 0.5, 0]) }
            await fixture.app.main.runScheduler(.physicsSync)
            try fixture.step(120)
            speeds.append(abs(try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody).getLinearVelocity().x))
        }
        #expect(speeds[0] > 1 && speeds[1] < speeds[0] * 0.5)
    }

    @Test func chainsLiveMaterialsAndLegacySerialization() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let chain = try Shape2DResource.generateChain(points: [[-3, 0], [-2, 0], [0, 0], [2, 0], [3, 0]])
        let entity = fixture.app.main.spawn { Collision2DComponent(shapes: [chain]); Transform() }
        await fixture.app.main.runScheduler(.physicsSync)
        entity.components[Collision2DComponent.self]?.material = try PhysicsMaterial.generate2D(friction: 0.8, rollingResistance: 0.2, surfaceSpeed: 4)
        await fixture.app.main.runScheduler(.physicsSync)
        let shapes = try #require(entity.components[Collision2DComponent.self]?.runtimeBody).getShapes()
        #expect(!shapes.isEmpty)
        for shape in shapes {
            let surface = b2Shape_GetSurfaceMaterial(shape.nativeID)
            #expect(surface.friction == 0.8 && surface.rollingResistance == 0.2 && surface.tangentSpeed == 4)
        }
        let data = Data(#"{"friction":0.6,"restitution":0.1,"density":1}"#.utf8)
        let legacy = try JSONDecoder().decode(PhysicsMaterial.self, from: data)
        #expect(legacy.rollingResistance == 0 && legacy.surfaceSpeed == 0)
        let material = try PhysicsMaterial.generate2D(rollingResistance: 0.2, surfaceSpeed: -3)
        let decoded = try JSONDecoder().decode(PhysicsMaterial.self, from: JSONEncoder().encode(material))
        #expect(decoded.rollingResistance == 0.2 && decoded.surfaceSpeed == -3)
        #expect(throws: PhysicsMaterialError.invalidProperties) { try PhysicsMaterial.generate2D(rollingResistance: -1) }
    }
}
