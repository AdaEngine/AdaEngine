@testable import AdaRender
import Testing
@testable import AdaText

struct HarfBuzzShaperTests {

    @Test
    func fontHandleCanResolveGlyphByGlyphIndex() throws {
        try Self.setupHeadlessRenderEngineIfNeeded()

        let font = FontResource.system(weight: .regular, emFontScale: 52)
        let scalarGlyph = try #require(font.handle.getGlyph(for: UnicodeScalar("A").value))

        #expect(font.handle.getGlyph(forGlyphIndex: scalarGlyph.glyphIndex) != nil)
    }

    @Test
    func textShaperShapesUTF8Text() throws {
        try Self.setupHeadlessRenderEngineIfNeeded()

        let font = FontResource.system(weight: .regular, emFontScale: 52)
        let shapedText = TextShaper.shape("Hello", font: font)

        #expect(!shapedText.isEmpty)
        #expect(shapedText.allSatisfy { $0.glyphIndex >= 0 })
    }

    private static func setupHeadlessRenderEngineIfNeeded() throws {
        guard unsafe RenderEngine.shared == nil else {
            return
        }

        unsafe RenderEngine.configurations.preferredBackend = .headless
        try RenderEngine.setupRenderEngine()
    }
}
