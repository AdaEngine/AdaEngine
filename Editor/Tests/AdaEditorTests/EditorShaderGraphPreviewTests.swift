@_spi(AdaEngine) import AdaEngine
import Testing

@testable import AdaEditor

@MainActor @Suite("Shader Graph preview", .serialized)
struct EditorShaderGraphPreviewTests {
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

}
