import Testing
@_spi(Internal) @testable import AdaECS
import Math

@Suite("World Tests")
struct WorldTests {
    let world: World

    init() {
        self.world = World()
    }

    @Test("Get resource")
    func getResource() {
        let resource = Gravity(value: Vector3(0, -9.8, 0))
        world.insertResource(resource)
        let resource2 = world.getResource(Gravity.self)
        #expect(resource == resource2)
    }

    @Test("Resource is unique")
    func resourceDoesNotOverride() {
        let resource = Gravity(value: Vector3(0, -9.8, 0))
        world.insertResource(resource)
        let resource2 = Gravity(value: Vector3(0, -90000.8, 0))
        world.insertResource(resource2)
        let resource3 = world.getResource(Gravity.self)
        #expect(resource == resource3)
    }

    @Test("Get mutable resource")
    func getMutableResource() throws {
        let resource = Gravity(value: Vector3(0, 9.8, 0))
        world.insertResource(resource)
        world.getMutableResource(Gravity.self).wrappedValue?.value = Vector3(0, -9.8, 0)
        #expect(world.getMutableResource(Gravity.self).wrappedValue?.value == Vector3(0, -9.8, 0))
    }

    @Test("Spawn empty entity")
    func spawnEmptyEntity() {
        let entity = world.spawn()
        #expect(entity.components.isEmpty)
    }

    @Test("Spawn entity with component")
    func spawnEntityWithComponent() {
        let transform = Transform(position: Vector3(0, 9.8, 0))
        let entity = world.spawn {
            transform
        }
        #expect(entity.components.count == 1)
        #expect(entity.components[Transform.self] == transform)
    }

    @Test("Remove entity")
    func removeEntity() {
        let entity = world.spawn()
        world.removeEntity(entity)
        #expect(world.entities.entities.count == 0)
    }

    @Test("Command spawn")
    func commandSpawn() {
        let transform = Transform(position: Vector3(0, 9.8, 0))
        world.commands.spawn {
            transform
        }
        world.flush()
        #expect(world.entities.entities.count == 1)
    }

    @Test("Clear world")
    func clearAllWorld() {
        let entityCount = 1000
        for i in 0..<entityCount {
            world.spawn {
                ComponentA(value: i)
                ComponentB(value: "abc")
            }
        }

        let query = Query<ComponentA>()
        query.update(from: world)

        #expect(query.count == entityCount)

        world.clear()

        #expect(world.entities.entities.isEmpty)
        #expect(world.addedEntities.isEmpty)
        #expect(world.removedEntities.isEmpty)

        query.update(from: world)
        #expect(query.count == 0)
    }
}
