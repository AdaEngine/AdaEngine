import AdaEngine
@_spi(Internal) @testable import AdaApp
@testable import AdaPhysics
@_spi(Internal) @testable import AdaRender
import Foundation
import Testing

@MainActor
@Suite("Voxel physics", .serialized)
struct VoxelPhysicsSystemTests {
    private static let voxelSize: Float = 0.25

    private static func makeApp() async throws -> AppWorlds {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        let app = AppWorlds(main: World())
        app
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(TransformPlugin())
            .addPlugin(RenderWorldPlugin())
            .addPlugin(Model3DPlugin())
            .addPlugin(Physics3DPlugin())
        try await app.build()
        return app
    }

    private static func settle(_ app: AppWorlds, storage: VoxelWorldStorage) async {
        var updates = 0
        while storage.hasDirtyChunks, updates < 20 {
            await app.main.runScheduler(.preUpdate)
            updates += 1
        }
        await app.main.runScheduler(.preUpdate)
        await app.main.runScheduler(.physicsSync)
    }

    private static func simulate(_ app: AppWorlds, steps: Int) async {
        await app.main.runScheduler(.physicsSync)
        app.main.insertResource(FixedTime(deltaTime: 1 / 60))
        for _ in 0..<steps {
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
        }
    }

    private static func colliders(of owner: Entity) -> [Entity] {
        owner.children.filter { $0.components[PhysicsBody3DComponent.self] != nil }
    }

    @Test("chunk colliders stop a sphere sweep on the terrain surface")
    func chunkCollidersBlockSweeps() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: Self.voxelSize, generatesColliders: true)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }
        // A 40 x 8 x 40 voxel slab spanning two chunks in X and Z: surface at y = 8 * 0.25 = 2.
        component.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(39, 7, 39), color: 1)
        await Self.settle(app, storage: component.storage)

        #expect(Self.colliders(of: owner).count == 4)
        let physics = try #require(app.main.physicsWorld3D)
        // Over the first chunk, and over the second one across the chunk border.
        for x: Float in [2, 9] {
            let fraction = physics.sphereCastFraction(from: [x, 5, 3], to: [x, -1, 3], radius: 0.25)
            #expect(abs(fraction - (5 - 2 - 0.25) / 6) < 0.01)
        }
        // Outside the slab nothing is hit.
        #expect(physics.sphereCastFraction(from: [20, 5, 3], to: [20, -1, 3], radius: 0.25) == 1)
    }

    @Test("editing voxels rebuilds the collider")
    func editsRebuildColliders() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: Self.voxelSize, generatesColliders: true)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }
        component.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(15, 7, 15), color: 1)
        await Self.settle(app, storage: component.storage)
        let physics = try #require(app.main.physicsWorld3D)
        // The shaft below spans cells 6...11, that is x and z in 1.5...3.0 units.
        func sweep(x: Float, z: Float) -> Float {
            physics.sphereCastFraction(from: [x, 5, z], to: [x, -1, z], radius: 0.2)
        }
        #expect(sweep(x: 2.2, z: 2.2) < 1)
        #expect(sweep(x: 0.5, z: 0.5) < 1)

        // Dig a shaft through the slab.
        component.storage.fill(from: SIMD3(6, 0, 6), to: SIMD3(11, 7, 11), color: 0)
        await Self.settle(app, storage: component.storage)
        await Self.settle(app, storage: component.storage)

        // The sphere falls through the shaft, while the untouched surface still blocks it.
        #expect(sweep(x: 2.2, z: 2.2) == 1)
        #expect(sweep(x: 0.5, z: 0.5) < 1)
        #expect(!Self.colliders(of: owner).isEmpty)

        // Clearing everything removes the colliders.
        component.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(15, 7, 15), color: 0)
        await Self.settle(app, storage: component.storage)
        await Self.settle(app, storage: component.storage)
        #expect(Self.colliders(of: owner).isEmpty)
        #expect(component.storage.colliderEntities.isEmpty)
    }

    @Test("colliders are placed in world space and follow a moving world")
    func collidersFollowTheWorldTransform() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: Self.voxelSize, generatesColliders: true)
        let owner = app.main.spawn("World") {
            component
            Transform(position: [10, 0, 0])
        }
        component.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(15, 7, 15), color: 1)
        await Self.settle(app, storage: component.storage)
        let physics = try #require(app.main.physicsWorld3D)

        func hits(x: Float) -> Bool {
            physics.sphereCastFraction(from: [x, 5, 2], to: [x, -1, 2], radius: 0.2) < 1
        }
        // The slab spans x = 0...4 in the world's space, so 10...14 in world space.
        #expect(hits(x: 12))
        #expect(!hits(x: 2))

        owner.components[Transform.self] = Transform(position: [30, 0, 0])
        for _ in 0..<3 {
            await app.main.runScheduler(.postUpdate)
            await app.main.runScheduler(.preUpdate)
            await app.main.runScheduler(.physicsSync)
        }
        #expect(hits(x: 32))
        #expect(!hits(x: 12))
    }

    @Test("a block lands flat on a thin platform in a translated world", arguments: [Float(0.1), Float(0.25)], [false, true])
    func blockLandsOnThinPlatform(voxelSize: Float, translated: Bool) async throws {
        let app = try await Self.makeApp()
        let offset: Vector3 = translated ? [-1.2, 0, 0.4] : .zero
        let component = VoxelWorld3DComponent(voxelSize: voxelSize, meshingBudget: 32, generatesColliders: true)
        app.main.spawn("World") {
            component
            Transform(position: offset)
        }
        let storage = component.storage
        storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(23, 3, 23), color: 1)
        storage.fill(from: SIMD3(11, 4, 11), to: SIMD3(12, 15, 12), color: 3)
        storage.fill(from: SIMD3(8, 16, 8), to: SIMD3(15, 23, 15), color: 2)
        await Self.settle(app, storage: storage)

        let cut = (4...15).flatMap { y in (11...12).flatMap { z in (11...12).map { x in SIMD3(x, y, z) } } }
        for point in cut {
            storage.setVoxel(x: point.x, y: point.y, z: point.z, color: 0)
        }
        let island = try #require(storage.detachFloatingIslands(around: cut, isAnchored: { $0.y <= 3 }).first)
        let body = try #require(
            island.spawnBody(
                in: app.main,
                palette: component.palette,
                voxelSize: voxelSize,
                worldTransform: Transform(position: offset).matrix
            )
        )
        await Self.settle(app, storage: storage)
        await Self.simulate(app, steps: 240)

        // The platform is 4 voxels thick and the block 8 voxels tall: it rests with its center 8 voxels above the ground.
        let endY = try #require(body.components[Transform.self]).position.y
        #expect(abs(endY - 8 * voxelSize) < voxelSize * 1.5, "voxelSize \(voxelSize) translated \(translated): endY \(endY)")
    }

    @Test("worlds without colliders create no physics bodies")
    func collidersAreOptIn() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: Self.voxelSize)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }
        component.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(7, 7, 7), color: 1)
        await Self.settle(app, storage: component.storage)

        #expect(Self.colliders(of: owner).isEmpty)
    }

    @Test("a cut-off island becomes a dynamic body that falls onto the ground")
    func detachedIslandFalls() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: Self.voxelSize, generatesColliders: true)
        app.main.spawn("World") {
            component
            Transform()
        }
        let storage = component.storage
        // Ground: 24 x 2 x 24 voxels, top surface at y = 0.5. A pillar at (12, 2...9) carries a 4x4x4 block on top.
        storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(23, 1, 23), color: 1)
        storage.fill(from: SIMD3(12, 2, 12), to: SIMD3(12, 9, 12), color: 1)
        storage.fill(from: SIMD3(11, 10, 11), to: SIMD3(14, 13, 14), color: 2)
        await Self.settle(app, storage: storage)

        // Cut the pillar just under the block and take the floating part with the block.
        let cut = (3...9).map { SIMD3(12, $0, 12) }
        for point in cut {
            storage.setVoxel(x: point.x, y: point.y, z: point.z, color: 0)
        }
        // The pillar piece (7 voxels) was cleared above; what is left of the block floats.
        let islands = storage.detachFloatingIslands(around: cut, isAnchored: { $0.y <= 1 })
        let island = try #require(islands.first)
        #expect(islands.count == 1)
        #expect(island.voxelCount == 64)

        let body = try #require(
            island.spawnBody(in: app.main, palette: component.palette, voxelSize: Self.voxelSize, worldTransform: .identity)
        )
        let startY = try #require(body.components[Transform.self]).position.y
        // Block center: cells 10...13 + half of 4 = y 12 cells = 3.0 units.
        #expect(abs(startY - 3.0) < 0.001)
        #expect(body.components[PhysicsBody3DComponent.self]?.mode == .dynamic)
        let mass = try #require(body.components[PhysicsBody3DComponent.self]).massProperties.mass
        #expect(abs(mass - 64 * 0.25 * 0.25 * 0.25 * 800) < 0.1)

        await Self.settle(app, storage: storage)
        await Self.simulate(app, steps: 240)

        let endY = try #require(body.components[Transform.self]).position.y
        // It dropped, and rests on the ground (top at 0.5) or on the pillar stub (top at 3 * 0.25) instead of falling through.
        #expect(endY < startY - 1)
        #expect(endY > 0.5)
        #expect(endY < 0.5 + 1.2)
    }
}
