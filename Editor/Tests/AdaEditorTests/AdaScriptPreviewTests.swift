@_spi(AdaEngine) import AdaEngine
import Foundation
import Testing

@testable import AdaEditor

@MainActor
@Suite("AdaScript preview availability")
struct AdaScriptPreviewTests {
    @Test("Unavailable AdaScript UI declarations stay out of the preview picker")
    func scannerDoesNotAdvertiseUnsupportedViews() {
        let source = "@previewable @view class HUD { func body() { Text(\"Score\"); } }"
        #expect(EditorPreviewScanner.declarations(in: source, language: .ada).isEmpty)
        #expect(!EditorNewFileGroup.adaScript.templates.contains(.uiScript))
    }

    @Test("An explicit legacy preview request reports that UI views are unavailable")
    func legacyBuildFailsClearly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaPreview-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = "@view class HUD { func body() { Text(\"Score\"); } }"
        let url = root.appendingPathComponent("HUD.ada")
        try source.write(to: url, atomically: true, encoding: .utf8)
        let document = EditorTextDocument(id: "hud", title: "HUD.ada", relativePath: "HUD.ada", absolutePath: url.path, language: .ada, content: source)
        let request = EditorAdaScriptPreviewBuildRequest(projectURL: root, document: document, packageModel: nil,
            declaration: .init(id: "HUD", title: "HUD", typeName: "HUD", line: 1, kind: .adaScript))
        await #expect(throws: EditorPreviewBuildFailure(message: "AdaUI views in AdaScript are temporarily unavailable.")) {
            try await EditorAdaScriptPreviewBuilder().build(request)
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == source)
    }
}
