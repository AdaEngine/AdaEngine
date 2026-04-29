import Testing
import AdaText
@testable import AdaPlatform
import AdaUtils
@testable import AdaUI

@MainActor
struct TextMarkdownTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func stringInitializerKeepsMarkdownLiteral() {
        let text = Text("**Hello**")

        #expect(text.storage.text.text == "**Hello**")
    }

    @Test
    func markdownInitializerBuildsAttributedStorage() {
        let text = Text(markdown: "**Hello**")

        #expect(text.storage.text.text == "Hello")
        #expect(firstAttributes(in: text.storage.text).fontTraits == TextFontTraits.strong)
    }

    @Test
    func environmentFontPreservesMarkdownTraitsAndScale() {
        let text = Text(markdown: "# Hello")
        var environment = EnvironmentValues()
        environment.font = Font.system(size: 20)

        let attributedText = text.storage.applyingEnvironment(environment)
        let attributes = firstAttributes(in: attributedText)

        #expect(attributes.fontTraits == TextFontTraits.strong)
        #expect(attributes.fontScale == 1.6)
        #expect(attributes.font.pointSize == 32)
    }

    private func firstAttributes(in text: AttributedText) -> TextAttributeContainer {
        text.attributes(at: text.startIndex)
    }
}
