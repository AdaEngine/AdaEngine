import AdaEngine
@_spi(Internal) @testable import AdaApp
@_spi(Internal) @testable import AdaRender
import Testing

@MainActor
@Suite("Model3D render item extraction")
struct Model3DRenderItemsExtractionTests {

    @Test("opaque 3D render items survive render-world pre-update")
    func opaque3DRenderItemsSurviveRenderWorldPreUpdate() async throws {
        try Self.setupHeadlessRenderEngineIfNeeded()

        let app = AppWorlds(main: World())
        app
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(TransformPlugin())
            .addPlugin(RenderWorldPlugin())
            .addPlugin(Model3DPlugin())

        try await app.build()

        let meshEntity = app.main.spawn("Cube") {
            Mesh3DComponent(
                mesh: Self.makeTriangleMesh(),
                materials: [PBRMaterial()]
            )
            Transform(position: [1, 2, 3])
        }

        await app.main.runScheduler(.preUpdate)

        let renderWorld = try #require(app.getSubworldBuilder(by: .renderWorld)?.main)
        renderWorld.insertResource(MainWorld(world: app.main))
        await renderWorld.runScheduler(.extract)

        let extractedItems = try #require(renderWorld.getResource(RenderItems<Opaque3DRenderItem>.self))
        #expect(extractedItems.items.count == 1)
        #expect(extractedItems.items.first?.entity == meshEntity.id)

        await renderWorld.runScheduler(.preUpdate)

        let preparedItems = try #require(renderWorld.getResource(RenderItems<Opaque3DRenderItem>.self))
        #expect(preparedItems.items.count == 1)
        #expect(preparedItems.items.first?.entity == meshEntity.id)
    }

    private static func setupHeadlessRenderEngineIfNeeded() throws {
        guard unsafe RenderEngine.shared == nil else {
            return
        }

        unsafe RenderEngine.configurations.preferredBackend = .headless
        try RenderEngine.setupRenderEngine()
    }

    private static func makeTriangleMesh() -> Mesh {
        let device = unsafe RenderEngine.shared.renderDevice
        var descriptor = MeshDescriptor(name: "Triangle")
        descriptor.positions = MeshBuffer([
            Vector3(0, 0.5, 0),
            Vector3(-0.5, -0.5, 0),
            Vector3(0.5, -0.5, 0)
        ])
        descriptor.normals = MeshBuffer([
            Vector3(0, 0, 1),
            Vector3(0, 0, 1),
            Vector3(0, 0, 1)
        ])
        descriptor.indicies = [0, 1, 2]
        return Mesh.generate(from: [descriptor], renderDevice: device)
    }
}
