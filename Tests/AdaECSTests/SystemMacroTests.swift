//
//  SystemMacroTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 05.06.2025.
//

import Testing
@testable import AdaECS
import Math

@Suite
struct SystemMacroTests {

    @Test
    func testBasicSystemMacro() throws {
        let world = World()
        let system = BasicSystem(world: world)
        #expect(system.queries.queries.count == 1)
    }

    @Test
    func testSystemWithDependencies() throws {
        #expect(DependentSystem.dependencies.count == 1)
        #expect(DependentSystem.dependencies[0] == .after(PhysicsSystem.self))
    }

    @Test
    func testSystemWithResources() throws {
        let world = World()
        world.insertResource(Gravity(value: Vector3(0, -9.8, 0)))
        let system = ResourceSystem(world: world)
        #expect(system.queries.queries.count == 1)
    }

    @Test
    func testPlainSystemWithResources() throws {
        let world = World()
        world.insertResource(Gravity(value: Vector3(0, -9.8, 0)))
        let system = PlainResourceSystem(world: world)
        #expect(system.queries.queries.count == 1)
    }

    @Test
    func testSystemWithUpdateContext() throws {
        let world = World(name: "PlainContext")
        let system = PlainContextSystem(world: world)

        #expect(system.queries.queries.count == 0)
    }

    @Test
    func testPlainSystemMacro() throws {
        let world = World(name: "PlainWorld")
        let system = PlainTransformSystem(world: world)

        #expect(system.queries.queries.count == 1)
    }
}

struct Gravity: Resource {
    var value: Vector3
}

@System
struct BasicSystem {
    @Query<Ref<Transform>, Velocity>
    private var query

    init(world: World) {}

    func update(context: inout UpdateContext) {
        query.forEach { (transform, velocity) in
            transform.position += velocity.velocity
        }
    }
}

@PlainSystem
func PlainTransform(
    _ query: Query<Ref<Transform>>
) {
    for transform in query.wrappedValue {
        transform.position += Vector3(1, 0, 0)
    }
}

@PlainSystem
func PlainContext(
    _ context: inout WorldUpdateContext
) {
    #expect(context.world.name == "PlainContext")
}

@PlainSystem
func PlainWorld(
    _ world: World
) {
    #expect(world.name == "PlainWorld")
}

@System
struct PhysicsSystem {
    init(world: World) { }

    func update(context: inout UpdateContext) {}
}

@System(dependencies: [
    .after(PhysicsSystem.self)
])
struct DependentSystem: System {
    @Query<Ref<Transform>>
    private var query

    init(world: World) {}

    func update(context: inout UpdateContext) {
        for transform in query {
            transform.position += Vector3(1, 0, 0)
        }
    }
}

@System
struct ResourceSystem {
    @ResQuery
    private var gravity: Gravity?

    init(world: World) { }

    func update(context: inout UpdateContext) {
        #expect(gravity != nil)
    }
}

@PlainSystem
func PlainResource(
    _ gravity: ResQuery<Gravity>
) {
    #expect(gravity.wrappedValue != nil)
}

