import AdaEngine
@_spi(Internal) @testable import AdaApp
@_spi(Internal) @testable import AdaRender
import Foundation
import Testing

/// Voxel models reach the 3D renderer as ordinary meshes, so copies made from one asset share their buffers and
/// material and are drawn as one instanced batch per mesh.
@MainActor
@Suite("Voxel instancing", .serialized)
struct VoxelInstancingTests {
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

    private static func fixtureFile(_ name: String) async throws -> VOXFile {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AdaAssetsTests/Fixtures/vox/\(name).vox")
        return try await VOXLoader().load(url: url)
    }

    private static func extractedItems(_ app: AppWorlds) async throws -> [Opaque3DRenderItem] {
        await app.main.runScheduler(.preUpdate)
        let renderWorld = try #require(app.getSubworldBuilder(by: .renderWorld)?.main)
        renderWorld.insertResource(MainWorld(world: app.main))
        await renderWorld.runScheduler(.extract)
        await renderWorld.runScheduler(.preUpdate)
        return try #require(renderWorld.getResource(RenderItems<Opaque3DRenderItem>.self)).items
    }

    @Test("copies of a single-mesh voxel model are drawn as one instanced batch")
    func copiesShareOneBatch() async throws {
        let app = try await Self.makeApp()
        let model = ModelAsset3D(voxelFile: try await Self.fixtureFile("castle"))
        let copies = 6
        for index in 0..<copies {
            let root = model.instantiate(in: app.main)
            root.components[Transform.self] = Transform(position: [Float(index) * 3, 0, 0])
        }

        let items = try await Self.extractedItems(app)
        #expect(items.count == 1)
        #expect(items.first?.batchRange?.count == copies)
    }

    @Test("separately imported copies do not share buffers and are not batched")
    func separateImportsDoNotBatch() async throws {
        let app = try await Self.makeApp()
        let file = try await Self.fixtureFile("castle")
        for index in 0..<2 {
            let root = ModelAsset3D(voxelFile: file).instantiate(in: app.main)
            root.components[Transform.self] = Transform(position: [Float(index) * 3, 0, 0])
        }

        let items = try await Self.extractedItems(app)
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.batchRange?.count == 1 })
    }
}
