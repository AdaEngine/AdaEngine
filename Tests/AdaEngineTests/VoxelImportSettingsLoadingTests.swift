import AdaEngine
@_spi(Internal) @testable import AdaApp
@_spi(Internal) @testable import AdaRender
import Foundation
import Testing

@MainActor
@Suite("Voxel import settings loading", .serialized)
struct VoxelImportSettingsLoadingTests {
    private static func fixturePath(_ name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AdaAssetsTests/Fixtures/vox/\(name).vox")
            .path
    }

    private static func prepareEngine() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
    }

    /// Largest extent of the whole model along any axis, from the bounds of its meshes.
    private static func extent(of model: ModelAsset3D) -> Float {
        var minimum = Vector3(Float.greatestFiniteMagnitude)
        var maximum = Vector3(-Float.greatestFiniteMagnitude)
        for mesh in model.meshes {
            let bounds = mesh.bounds
            minimum = min(minimum, bounds.min)
            maximum = max(maximum, bounds.max)
        }
        return max(maximum.x - minimum.x, max(maximum.y - minimum.y, maximum.z - minimum.z))
    }

    @Test("the voxel size in the asset query scales the imported model")
    func voxelSizeQueryScalesTheModel() async throws {
        try Self.prepareEngine()
        let path = Self.fixturePath("castle")

        let normal = try #require(try await AssetsManager.load(ModelAsset3D.self, at: path).asset)
        let doubled = try #require(try await AssetsManager.load(ModelAsset3D.self, at: path + "#voxelSize=0.2").asset)

        // The castle is 16 voxels wide: 1.6 units at the default 0.1 and 3.2 at 0.2.
        #expect(abs(Self.extent(of: normal) - 1.6) < 0.01)
        #expect(abs(Self.extent(of: doubled) - 3.2) < 0.01)
    }

    @Test("a source with voxel settings loads through its asset path")
    func sourceSettingsReachTheImporter() async throws {
        try Self.prepareEngine()
        let source = Model3DSource(source: Self.fixturePath("castle"), voxel: VoxelImportSettings(voxelSize: 0.05))

        let model = try #require(try await AssetsManager.load(ModelAsset3D.self, at: source.assetPath).asset)
        #expect(abs(Self.extent(of: model) - 0.8) < 0.01)
    }

    @Test("merge static and frame rate settings are applied")
    func mergeStaticAndFramesPerSecond() async throws {
        try Self.prepareEngine()
        let path = Self.fixturePath("robot")

        let separate = try #require(try await AssetsManager.load(ModelAsset3D.self, at: path).asset)
        let merged = try #require(try await AssetsManager.load(ModelAsset3D.self, at: path + "#mergeStatic=1&fps=10").asset)

        // Each static subtree (body, head) collapses into one node that carries its mesh; the animated arm keeps its shape node.
        #expect(merged.nodes.count < separate.nodes.count)
        #expect(separate.nodes.first { $0.name == "body" }?.meshIndex == nil)
        #expect(merged.nodes.first { $0.name == "body" }?.meshIndex != nil)
        #expect(merged.nodes.first { $0.name == "arm" }?.meshIndex == nil)
        #expect(separate.voxelTimeline?.framesPerSecond == 30)
        #expect(merged.voxelTimeline?.framesPerSecond == 10)
    }

    @Test("Model3DSource instantiates a voxel model with its settings")
    func sourceSystemUsesSettings() async throws {
        try Self.prepareEngine()
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin()).addPlugin(Model3DPlugin())
        try await app.build()

        let owner = app.main.spawn("Castle") {
            Model3DSource(source: Self.fixturePath("castle"), voxel: VoxelImportSettings(voxelSize: 0.2))
            Transform()
        }
        await app.main.runScheduler(.preUpdate)
        // The source system loads asynchronously and applies its result through commands.
        for _ in 0..<50 where owner.components[Model3DSourceState.self]?.rootEntityID == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
            await app.main.runScheduler(.preUpdate)
        }

        let state = try #require(owner.components[Model3DSourceState.self])
        #expect(state.error == nil)
        let root = try #require(state.rootEntityID.flatMap { app.main.getEntityByID($0) })
        var pending = root.children
        var largest: Float = 0
        while let entity = pending.popLast() {
            if let mesh = entity.components[Mesh3DComponent.self]?.mesh {
                largest = max(largest, mesh.bounds.max.x - mesh.bounds.min.x)
            }
            pending.append(contentsOf: entity.children)
        }
        #expect(abs(largest - 3.2) < 0.01)
    }
}
