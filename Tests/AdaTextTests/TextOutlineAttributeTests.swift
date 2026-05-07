import AdaUtils
import Foundation
import Testing
@testable import AdaText

struct TextOutlineAttributeTests {

    @Test
    func outlineAttributes_haveRenderableDefaultsAndCanBeCustomized() {
        var attributes = TextAttributeContainer()

        #expect(attributes.outlineColor == Color(red: 0, green: 0, blue: 0, alpha: 0))
        #expect(attributes.outlineWidth == 1)

        attributes.outlineColor = .white
        attributes.outlineWidth = 2.5

        let text = AttributedText("Outlined", attributes: attributes)
        let resolved = text.attributes(at: text.startIndex)

        #expect(resolved.outlineColor == .white)
        #expect(resolved.outlineWidth == 2.5)
    }

    @Test
    func outlineAttributes_areAppliedThroughDynamicAttributedTextMembers() {
        var text = AttributedText("Title")

        text.outlineColor = .white
        text.outlineWidth = 3

        for index in text.text.indices {
            let attributes = text.attributes(at: index)
            #expect(attributes.outlineColor == .white)
            #expect(attributes.outlineWidth == 3)
        }
    }

    @Test
    func textShader_usesExplicitVaryingLocationsForMetalCompatibility() throws {
        let shaderURL = Bundle.module.url(forResource: "text", withExtension: "glsl", subdirectory: "Assets")
        let shader = try #require(shaderURL.map { try String(contentsOf: $0, encoding: .utf8) })

        #expect(shader.contains("layout (location = 0) out vec4 v_ForegroundColor;"))
        #expect(shader.contains("layout (location = 1) out vec4 v_OutlineColor;"))
        #expect(shader.contains("layout (location = 2) out float v_OutlineWidth;"))
        #expect(shader.contains("layout (location = 3) out vec2 v_TexCoordinate;"))
        #expect(shader.contains("layout (location = 0) in vec4 v_ForegroundColor;"))
        #expect(shader.contains("layout (location = 1) in vec4 v_OutlineColor;"))
        #expect(shader.contains("layout (location = 2) in float v_OutlineWidth;"))
        #expect(shader.contains("layout (location = 3) in vec2 v_TexCoordinate;"))
    }
}
