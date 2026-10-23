@_spi(Internal) @testable import AdaApp
import AdaECS
import AdaNavigation
import AdaNavigationBaking
import AdaPhysics
import AdaScene
import AdaTransform
import Math
import Testing

@MainActor
@Suite("Navigation character integration", .serialized)
struct Navigation3DTests {
    @Test("A scheduled navigation agent reaches its destination through the physics controller", arguments: [false, true])
    func characterFollowsRoute(aroundObstacle: Bool) async throws {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin())
            .addPlugin(Physics3DPlugin())
            .addPlugin(TransformPlugin())
            .addPlugin(Navigation3DPlugin())
        try await app.build()
        app.main.spawn {
            PhysicsBody3DComponent(shapes: [.generateBox(width: 14, height: 1, depth: 14)], mode: .static)
            Transform(position: [6, -0.5, 6])
        }
        if aroundObstacle {
            app.main.spawn {
                PhysicsBody3DComponent(shapes: [.generateBox(width: 4, height: 3, depth: 4)], mode: .static)
                Transform(position: [6, 1.5, 6])
            }
        }
        let rectangles: [(Float, Float, Float, Float)] = aroundObstacle
            ? [(0, 4, 0, 12), (8, 12, 0, 12), (4, 8, 0, 4), (4, 8, 8, 12)]
            : [(0, 12, 0, 12)]
        var vertices: [Vector3] = []
        var indices: [UInt32] = []
        for (minX, maxX, minZ, maxZ) in rectangles {
            let offset = UInt32(vertices.count)
            vertices += [[minX, 0, minZ], [minX, 0, maxZ], [maxX, 0, maxZ], [maxX, 0, minZ]]
            indices += [0, 1, 2, 0, 2, 3].map { offset + $0 }
        }
        let data = try await NavigationMeshBaker.bake(
            vertices: vertices,
            indices: indices
        )
        let mesh = try NavigationMesh(data: data)
        let route = try await mesh.findPath(from: [1, 0, 6], to: [11, 0, 6])
        var follower = NavigationPathFollower()
        follower.follow(route)
        let character = app.main.spawn {
            NavigationAgent3DComponent(follower: follower)
            CharacterController3DComponent()
            Transform(position: [1, 0, 6])
        }
        await app.main.runScheduler(.physicsSync)
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        for _ in 0..<600 {
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
        }
        let position = try #require(character.components[Transform.self]).position
        let agent = try #require(character.components[NavigationAgent3DComponent.self])
        #expect(agent.lastError == nil)
        #expect(agent.follower.state == .arrived)
        #expect((Vector3(position.x, 0, position.z) - Vector3(11, 0, 6)).length < 0.25)
        #expect(abs(position.y) < 0.05)
        #expect(try #require(character.components[CharacterController3DComponent.self]).desiredVelocity == .zero)
    }
}
