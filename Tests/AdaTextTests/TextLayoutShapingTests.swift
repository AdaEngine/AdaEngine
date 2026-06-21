@testable import AdaRender
import Testing
@testable import AdaText

struct TextLayoutShapingTests {

    @Test
    func layoutUsesHarfBuzzGlyphSequenceForLigatureText() throws {
        try Self.setupHeadlessRenderEngineIfNeeded()

        var attributes = TextAttributeContainer()
        attributes.font = .system(size: 32)
        let text = AttributedText("fi", attributes: attributes)
        let shapedGlyphs = TextShaper.shape(text.text, font: attributes.font.fontResource)

        #expect(shapedGlyphs.count == 1)

        let layoutManager = TextLayoutManager()
        layoutManager.setTextContainer(
            TextContainer(
                text: text,
                textAlignment: .leading,
                lineBreakMode: .byCharWrapping
            )
        )
        layoutManager.fitToSize(.infinity)

        let line = try #require(layoutManager.textLines.first)
        let run = try #require(line.runs.first)
        #expect(run.count == shapedGlyphs.count)
    }

    private static func setupHeadlessRenderEngineIfNeeded() throws {
        guard unsafe RenderEngine.shared == nil else {
            return
        }

        unsafe RenderEngine.configurations.preferredBackend = .headless
        try RenderEngine.setupRenderEngine()
    }
}
