import AdaEngine
@_spi(Internal) @testable import AdaApp
@_spi(Internal) @testable import AdaRender
import Foundation
import Testing

@MainActor
@Suite("Voxel world meshing", .serialized)
struct VoxelWorldSystemTests {
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
        try await app.build()
        return app
    }

    private static func chunks(of owner: Entity) -> [Entity] {
        owner.children.filter { $0.components[VoxelChunk3DComponent.self] != nil }
    }

    private static func indexCount(_ entity: Entity) -> Int? {
        entity.components[Mesh3DComponent.self]?.mesh.models.first?.parts.first?.indexCount
    }

    /// Runs the meshing scheduler until the dirty queue is empty, returning the number of updates it took.
    @discardableResult
    private static func settle(_ app: AppWorlds, storage: VoxelWorldStorage, limit: Int = 20) async -> Int {
        var updates = 0
        while storage.hasDirtyChunks, updates < limit {
            await app.main.runScheduler(.preUpdate)
            updates += 1
        }
        // One more pass applies the commands queued by the final meshing update.
        await app.main.runScheduler(.preUpdate)
        return updates
    }

    @Test("edited voxels become chunk mesh entities with positions")
    func buildsChunkEntities() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: 0.5)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }

        component.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(3, 3, 3), color: 1)
        await Self.settle(app, storage: component.storage)

        let chunks = Self.chunks(of: owner)
        #expect(chunks.count == 1)
        let chunk = try #require(chunks.first)
        // A 4x4x4 cube has six greedy quads.
        #expect(Self.indexCount(chunk) == 36)
        #expect(chunk.components[Transform.self]?.position == [0, 0, 0])
        #expect(chunk.components[VoxelChunk3DComponent.self]?.coordinate == VoxelChunkCoordinate(x: 0, y: 0, z: 0))
    }

    @Test("a voxel in a negative chunk is placed at its chunk origin")
    func placesNegativeChunks() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(voxelSize: 0.5)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }

        component.storage.setVoxel(x: -1, y: 0, z: 0, color: 2)
        // The voxel sits on a chunk border, so the neighbouring chunk is dirty too but has nothing to show.
        await Self.settle(app, storage: component.storage)

        let chunk = try #require(Self.chunks(of: owner).first)
        #expect(Self.chunks(of: owner).count == 1)
        #expect(chunk.components[VoxelChunk3DComponent.self]?.coordinate == VoxelChunkCoordinate(x: -1, y: 0, z: 0))
        // Chunk edge is 32 voxels * 0.5.
        #expect(chunk.components[Transform.self]?.position == [-16, 0, 0])
    }

    @Test("meshing is limited per update by the budget")
    func spreadsMeshingAcrossUpdates() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(meshingBudget: 2)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }
        // Six separate chunks along X, each with one interior voxel.
        for index in 0..<6 {
            component.storage.setVoxel(x: index * 32 + 10, y: 10, z: 10, color: 1)
        }

        await app.main.runScheduler(.preUpdate)
        // The budget is two chunks per update, so work is left over.
        #expect(Self.chunks(of: owner).count <= 2)
        #expect(component.storage.hasDirtyChunks)

        let updates = await Self.settle(app, storage: component.storage)
        #expect(updates >= 2)
        #expect(Self.chunks(of: owner).count == 6)
    }

    @Test("editing a voxel remeshes its chunk and clearing a chunk removes the entity")
    func remeshesAndRemoves() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent()
        let owner = app.main.spawn("World") {
            component
            Transform()
        }
        component.storage.setVoxel(x: 5, y: 5, z: 5, color: 1)
        await Self.settle(app, storage: component.storage)
        let chunk = try #require(Self.chunks(of: owner).first)
        #expect(Self.indexCount(chunk) == 36)

        // A second voxel two cells away adds six more faces.
        component.storage.setVoxel(x: 8, y: 5, z: 5, color: 1)
        await Self.settle(app, storage: component.storage)
        #expect(Self.chunks(of: owner).count == 1)
        #expect(Self.indexCount(try #require(Self.chunks(of: owner).first)) == 72)

        component.storage.setVoxel(x: 5, y: 5, z: 5, color: 0)
        component.storage.setVoxel(x: 8, y: 5, z: 5, color: 0)
        await Self.settle(app, storage: component.storage)
        #expect(Self.chunks(of: owner).isEmpty)
        #expect(component.storage.chunkEntities.isEmpty)
    }

    @Test("faces between neighbouring chunks are culled")
    func cullsFacesAcrossChunkBorders() async throws {
        let app = try await Self.makeApp()
        let component = VoxelWorld3DComponent(bakesAmbientOcclusion: false)
        let owner = app.main.spawn("World") {
            component
            Transform()
        }
        // Two cells touching across the x = 31 / 32 chunk border.
        component.storage.setVoxel(x: 31, y: 10, z: 10, color: 1)
        component.storage.setVoxel(x: 32, y: 10, z: 10, color: 1)
        await Self.settle(app, storage: component.storage)

        let chunks = Self.chunks(of: owner)
        #expect(chunks.count == 2)
        // Each cube lacks the face that touches its neighbour: five quads each.
        #expect(chunks.allSatisfy { Self.indexCount($0) == 30 })
    }
}
