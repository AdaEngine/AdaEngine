import Testing
import AdaECS
import Math
@testable import AdaApp
@testable import AdaTransform

@Suite("AdaTransform Tests")
struct AdaTransformTests: Sendable {

    let world: AppWorlds

    init() async throws {
        self.world = await AppWorlds(mainWorld: World())
            .addPlugin(TransformPlugin())

        try await self.world.build()
    }

    @Test("Global transform test")
    func globalTransformTest() async throws {
        let entity = Entity()
        entity.components += Transform()

        await world.update()

        let globalTransform = try #require(entity.components[GlobalTransform.self])
        #expect(globalTransform.matrix == Transform3D.identity)
    }

    @Test("Parent-child transform propagation test")
    func parentChildTransformPropagationTest() async throws {
        let parent = Entity()
        parent.components += Transform(position: Vector3(x: 10, y: 20, z: 30))

        let child = Entity()
        let childLocalTransform = Transform(position: Vector3(x: 5, y: 0, z: 0))
        child.components += childLocalTransform
        parent.addChild(child)

        await world.update()

        let childGlobalTransform = try #require(child.components[GlobalTransform.self])
        let expectedChildGlobalPosition = Vector3(x: 15, y: 20, z: 30)  // parent position + child local position

        #expect(childGlobalTransform.getTransform().position == expectedChildGlobalPosition)

        // Test moving parent
        parent.components[Transform.self]?.position = Vector3(x: 100, y: 200, z: 300)

        await world.update()

        let updatedChildGlobalTransform = try #require(child.components[GlobalTransform.self])
        let expectedUpdatedChildGlobalPosition = Vector3(x: 105, y: 200, z: 300)  // new parent position + child local position

        #expect(updatedChildGlobalTransform.getTransform().position == expectedUpdatedChildGlobalPosition)
    }
}

extension World {
    func update() async {
        await self.update(1 / 60)
    }
}
