import Testing
import AdaECS
import Math
@testable import AdaApp
@testable import AdaTransform

@Suite("AdaTransform Tests")
@MainActor
struct AdaTransformTests: Sendable {

    let world: AppWorlds

    init() async throws {
        self.world = AppWorlds(mainWorld: World())
            .addPlugin(TransformPlugin())

        try self.world.build()
    }

    @Test("Global transform test")
    func globalTransformTest() async throws {
        let entity = world.mainWorld.spawn {
            Transform()
        }
        await world.mainWorld.runScheduler(.postUpdate)

        let globalTransform = try #require(entity.components[GlobalTransform.self])
        #expect(globalTransform.matrix == Transform3D.identity)
    }

    @Test("Parent-child transform propagation test")
    func parentChildTransformPropagationTest() async throws {
        let parent = world.mainWorld.spawn {
            Transform(position: Vector3(x: 10, y: 20, z: 30))
        }
        let child = world.mainWorld.spawn {
            Transform(position: Vector3(x: 5, y: 0, z: 0))
        }
        parent.addChild(child)
        await world.mainWorld.runScheduler(.postUpdate)

        let childGlobalTransform = try #require(child.components[GlobalTransform.self])
        let expectedChildGlobalPosition = Vector3(x: 15, y: 20, z: 30)  // parent position + child local position

        #expect(childGlobalTransform.getTransform().position == expectedChildGlobalPosition)

        // Test moving parent
        parent.components[Transform.self]?.position = Vector3(x: 100, y: 200, z: 300)
        self.world.mainWorld.flush()

        await world.mainWorld.runScheduler(.postUpdate)

        let updatedChildGlobalTransform = try #require(child.components[GlobalTransform.self])
        let expectedUpdatedChildGlobalPosition = Vector3(x: 105, y: 200, z: 300)  // new parent position + child local position

        #expect(updatedChildGlobalTransform.getTransform().position == expectedUpdatedChildGlobalPosition)
    }
}
