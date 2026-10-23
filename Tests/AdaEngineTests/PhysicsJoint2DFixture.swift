@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Math
import Testing

@MainActor
struct PhysicsJoint2DFixture {
    let app: AppWorlds
    init(gravity: Vector2 = .zero) async throws {
        app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: gravity))
        try await app.build()
    }
    func body(at position: Vector2 = .zero, angle: Float = 0, mode: PhysicsBodyMode = .dynamic) -> Entity {
        app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 0.5, height: 1)], massProperties: .init(mass: 1, inertia: [0, 0, 1]), mode: mode)
            Transform(rotation: Quat(axis: [0, 0, 1], angle: angle), position: [position.x, position.y, 0])
        }
    }
    func connect(_ descriptor: PhysicsJoint2DDescriptor) async throws -> Entity {
        let owner = app.main.spawn { PhysicsJoint2DComponent(joint: descriptor) }
        await app.main.runScheduler(.physicsSync)
        #expect(owner.components[PhysicsJoint2DComponent.self]?.isConnected == true)
        return owner
    }
    func native(_ entity: Entity) throws -> b2JointId {
        try #require(entity.components[PhysicsJoint2DComponent.self]?.runtimeJoint).id
    }
    func step(_ count: Int = 180) throws {
        let physics = try #require(app.main.physicsWorld2D)
        for _ in 0..<count { physics.updateSimulation(1.0 / 60) }
    }
}
