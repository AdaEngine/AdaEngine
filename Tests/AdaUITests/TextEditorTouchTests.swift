import AdaInput
@testable import AdaPlatform
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@MainActor
struct TextEditorTouchTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func textEditor_touchMovesCaretToTappedPosition() throws {
        final class Model {
            var text = "alpha\nbeta"
        }

        let model = Model()
        let tester = ViewTester {
            TextEditor(
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        let touchPoint = Point(110, 48)
        let began = TouchEvent(window: .empty, location: touchPoint, phase: .began, time: 0)
        let node = try #require(tester.hitTest(touchPoint, event: began) as? TextEditorViewNode)
        let expectedOffset = node.closestOffset(to: node.convertPointFromRoot(touchPoint))

        tester.containerView.onTouchesEvent([began])
        tester.containerView.onTouchesEvent([
            TouchEvent(window: .empty, location: touchPoint, phase: .ended, time: 0.01)
        ])

        #expect(expectedOffset > 0)
        #expect(node.isFocused)
        #expect(node.caretOffset == expectedOffset)
        #expect(!node.hasSelection)
    }
}
