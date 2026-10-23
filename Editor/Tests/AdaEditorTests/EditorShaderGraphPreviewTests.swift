@_spi(Internal) @testable import AdaApp
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaRender
import Testing

@testable import AdaEditor

@MainActor @Suite("Shader Graph preview", .serialized)
struct EditorShaderGraphPreviewTests {
    @Test(arguments: [ShaderGraph.Target.sprite, .pbrSurface])
    func previewWorldInstallsEventsBeforeBuildingSystems(target: ShaderGraph.Target) async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        let preview = EditorShaderGraphPreview()
        preview.schedule(EditorShaderGraphTemplates.basic(target: target), basePath: nil)
        for _ in 0..<200 where preview.isCompiling { try await Task.sleep(for: .milliseconds(10)) }
        _ = try #require(preview.material)
        let app = AppWorlds(main: World(name: "Shader Graph preview lifecycle"))
        EditorShaderGraphViewport.configure(app, model: preview, camera: EditorModelPreviewCamera())
        MainSchedulerPlugin().setup(in: app)
        app.insertResource(OffscreenRenderWorld())
        app.insertResource(PrimaryWindowId(windowId: RID()))
        try await app.build()
        #expect(app.main.supportsEventDelivery)
        #expect(!app.main.getEntities().isEmpty)
        preview.cancel()
    }

    @Test func previewRejectsStaleRequestsAndKeepsTheLastValidMaterial() async throws {
        let preview = EditorShaderGraphPreview()
        let graph = EditorShaderGraphTemplates.basic(target: .pbrSurface)
        preview.schedule(graph, basePath: nil)
        for _ in 0..<200 where preview.isCompiling { try await Task.sleep(for: .milliseconds(10)) }
        let first = try #require(preview.material)
        var invalid = graph
        invalid.nodes[0].value = [.nan]
        preview.schedule(invalid, basePath: nil)
        for _ in 0..<200 where preview.isCompiling { try await Task.sleep(for: .milliseconds(10)) }
        #expect(preview.material === first)
        #expect(preview.error != nil && preview.isStale)
        preview.schedule(invalid, basePath: nil)
        var green = graph
        green.nodes[0].value = [0, 1, 0, 1]
        preview.schedule(green, basePath: nil)
        for _ in 0..<200 where preview.isCompiling { try await Task.sleep(for: .milliseconds(10)) }
        #expect(preview.material?.value(for: "tint") == [0, 1, 0, 1])
        #expect(preview.error == nil && !preview.isStale)
        preview.cancel()
    }

    @Test func deviceFailureRestoresTheLastPreparedMaterial() async throws {
        let preview = EditorShaderGraphPreview()
        let graph = EditorShaderGraphTemplates.basic(target: .pbrSurface)
        preview.schedule(graph, basePath: nil)
        for _ in 0..<200 where preview.isCompiling { try await Task.sleep(for: .milliseconds(10)) }
        let first = try #require(preview.material)
        first.recordPipelinePreparation()
        preview.checkDeviceError()
        var next = graph
        next.nodes[0].value = [0, 1, 0, 1]
        preview.schedule(next, basePath: nil)
        for _ in 0..<200 where preview.isCompiling { try await Task.sleep(for: .milliseconds(10)) }
        let failed = try #require(preview.material)
        #expect(failed !== first)
        failed.reportCompilationError(ShaderGraphDiagnostic(code: .invalidReference))
        preview.checkDeviceError()
        #expect(preview.material === first)
        #expect(preview.isStale && preview.error != nil)
        preview.cancel()
    }

}
