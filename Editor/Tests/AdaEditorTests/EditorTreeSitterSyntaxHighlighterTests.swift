@_spi(AdaEngine) import AdaEngine
@testable import AdaEditor
import Testing

@Suite("EditorTreeSitterSyntaxHighlighter")
struct EditorTreeSitterSyntaxHighlighterTests {
    @Test("highlights Swift Package manifests with tree-sitter query captures")
    func highlightsSwiftPackageManifestsWithTreeSitterQueryCaptures() throws {
        var palette = EditorCodeColorPalette.dark
        palette.keyword = .green
        palette.string = .blue
        palette.type = .orange
        palette.comment = .yellow
        palette.number = .red
        palette.punctuation = .purple

        let tokens = EditorSyntaxHighlighter.tokens(
            for: """
            @MainActor
            let enabled = true
            let package = Package(name: "Ada", platforms: [.macOS(.v15)]) // manifest
            """,
            language: .packageManifest,
            palette: palette
        )

        #expect(tokens.contains(EditorCodeToken(text: "@", color: .green)))
        #expect(tokens.contains(EditorCodeToken(text: "MainActor", color: .green)))
        #expect(tokens.contains(EditorCodeToken(text: "let", color: .green)))
        #expect(tokens.contains(EditorCodeToken(text: "Package", color: .orange)))
        #expect(tokens.contains(EditorCodeToken(text: "Ada", color: .blue)))
        #expect(tokens.contains(EditorCodeToken(text: "true", color: .red)))
        #expect(tokens.contains(EditorCodeToken(text: "// manifest", color: .yellow)))
    }

    @Test("maps tree-sitter multiline Swift captures to per-line editor spans")
    func mapsTreeSitterMultilineSwiftCapturesToPerLineEditorSpans() throws {
        var palette = EditorCodeColorPalette.dark
        palette.string = .blue

        let spans = EditorSyntaxHighlighter.spans(
            for: "let text = \"\"\"\nAda\nEngine\n\"\"\"",
            language: .swift,
            palette: palette
        )

        #expect(spans.contains(TextEditorTokenSpan(line: 0, startColumn: 11, length: 3, color: .blue)))
        #expect(spans.contains(TextEditorTokenSpan(line: 1, startColumn: 0, length: 3, color: .blue)))
        #expect(spans.contains(TextEditorTokenSpan(line: 2, startColumn: 0, length: 6, color: .blue)))
        #expect(spans.contains(TextEditorTokenSpan(line: 3, startColumn: 0, length: 3, color: .blue)))
    }
}
