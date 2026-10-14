@testable import AdaPlatform
@testable import AdaUI
import AdaUtils
import Math
import Testing

@MainActor
struct KeyboardOcclusionTests {
    init() async throws { try Application.prepareForTest() }

    @Test
    func keyboardOutsideCurrentDisplayLeavesContentVisible() {
        let bounds = Rect(x: 0, y: 0, width: 466, height: 678)
        let frames = [
            Rect(x: 0, y: 800, width: 951, height: 300),
            Rect(x: 600, y: 400, width: 350, height: 269),
            Rect(x: 0, y: 678, width: 466, height: 300),
            Rect.zero
        ]
        let tester = ViewTester { Color.white }.setSize(bounds.size)
        for keyboardFrame in frames {
            let occlusion = KeyboardOcclusion(viewBounds: bounds, keyboardFrame: keyboardFrame)
            #expect(occlusion.frame == .zero)
            #expect(occlusion.height == 0)
            tester.containerView.keyboardOccludedHeight = occlusion.height
            tester.performLayout()
            #expect(tester.containerView.viewTree.rootNode.frame.height == bounds.height)
        }
    }

    @Test
    func visibleKeyboardInsetsContentAndHideClearsStaleDisplayCoordinates() {
        let bounds = Rect(x: 0, y: 0, width: 951, height: 669)
        let keyboardFrame = Rect(x: 0, y: 400, width: 951, height: 269)
        let visible = KeyboardOcclusion(viewBounds: bounds, keyboardFrame: keyboardFrame)
        #expect(visible.frame == keyboardFrame)
        #expect(visible.height == 269)
        let hidden = KeyboardOcclusion(viewBounds: bounds, keyboardFrame: keyboardFrame, isHidden: true)
        #expect(hidden.frame == .zero)
        #expect(hidden.height == 0)
    }
}
