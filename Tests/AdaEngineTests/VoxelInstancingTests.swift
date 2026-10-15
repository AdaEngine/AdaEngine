@testable import AdaCorePipelines
import AdaEngine
@_spi(Internal) @testable import AdaApp
@_spi(Internal) @testable import AdaRender
import Foundation
import Testing

/// Voxel models reach the 3D renderer as ordinary meshes, so copies made from one asset share their buffers and
/// material and are drawn as one instanced batch per mesh part.
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

    private static func spawnCopies(of model: ModelAsset3D, count: Int, in app: AppWorlds) {
        for index in 0..<count {
            let root = model.instantiate(in: app.main)
            root.components[Transform.self] = Transform(position: [Float(index) * 0.5 - 1.2, 0, 5])
        }
    }

    @Test("copies of a single-mesh voxel model are drawn as one instanced batch")
    func copiesShareOneBatch() async throws {
        let app = try await Self.makeApp()
        let model = ModelAsset3D(voxelFile: try await Self.fixtureFile("castle"))
        Self.spawnCopies(of: model, count: 6, in: app)

        let visible = try await VisibleMesh3D.capture(from: app)
        #expect(visible.items.count == 1)
        #expect(visible.items.first?.batchRange?.count == 6)
    }

    @Test("a multi-part model is batched per part even though its copies interleave")
    func multiPartCopiesBatchPerPart() async throws {
        let app = try await Self.makeApp()
        let model = ModelAsset3D(voxelFile: try await Self.fixtureFile("robot"))
        let copies = 6
        Self.spawnCopies(of: model, count: copies, in: app)

        // The robot has three mesh parts (body, head, arm). Their copies interleave in entity order,
        // yet the visible list holds one draw per part with an instance for every copy.
        let visible = try await VisibleMesh3D.capture(from: app)
        #expect(visible.items.count == 3)
        #expect(visible.items.allSatisfy { $0.batchRange?.count == copies })
        #expect(visible.count.drawCalls == 3)
    }

    @Test("separately imported copies do not share buffers and are not batched")
    func separateImportsDoNotBatch() async throws {
        let app = try await Self.makeApp()
        let file = try await Self.fixtureFile("castle")
        for index in 0..<2 {
            let root = ModelAsset3D(voxelFile: file).instantiate(in: app.main)
            root.components[Transform.self] = Transform(position: [Float(index) * 0.5, 0, 5])
        }

        let visible = try await VisibleMesh3D.capture(from: app)
        #expect(visible.items.count == 2)
        #expect(visible.items.allSatisfy { $0.batchRange?.count == 1 })
    }
}
