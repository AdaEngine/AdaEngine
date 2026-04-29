import Testing
@testable import AdaPlatform
@testable import AdaUI
import AdaUtils
import Math

@MainActor
struct TextRenderingRegressionTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func geometryReader_placesChildIntoAvailableBounds() {
        let tester = ViewTester {
            GeometryReader { _ in
                Color.red
                    .accessibilityIdentifier("geometry-content")
            }
        }
        .setSize(Size(width: 1200, height: 800))
        .performLayout()

        let contentNode = tester.findNodeByAccessibilityIdentifier("geometry-content")

        #expect(contentNode?.frame == Rect(x: 0, y: 0, width: 1200, height: 800))
    }

    @Test
    func geometryReader_childDrawsUsingContainerSize() {
        let tester = ViewTester {
            GeometryReader { _ in
                Color.red
            }
        }
        .setSize(Size(width: 1200, height: 800))
        .performLayout()

        let context = UIGraphicsContext()
        tester.containerView.viewTree.rootNode.draw(with: context)

        let hasVisibleQuad = context.getDrawCommands().contains { command in
            guard case let .drawQuad(transform, _, _) = command else {
                return false
            }
            return transform == Rect(x: 0, y: 0, width: 1200, height: 800).toTransform3D
        }

        #expect(hasVisibleQuad)
    }

    @Test
    func geometryReader_keepsFixedSizeChildAtTopLeadingOrigin() {
        let tester = ViewTester {
            GeometryReader { _ in
                Color.red
                    .frame(width: 100, height: 50)
                    .accessibilityIdentifier("geometry-fixed-child")
            }
        }
        .setSize(Size(width: 1200, height: 800))
        .performLayout()

        let childNode = tester.findNodeByAccessibilityIdentifier("geometry-fixed-child")

        #expect(childNode?.frame == Rect(x: 0, y: 0, width: 100, height: 50))
    }

    @Test
    func wrappedTextReportsVisualLineHeight() {
        let tester = ViewTester {
            Text("This is a long chat message that should wrap into multiple visual rows.")
                .font(.system(size: 17))
                .frame(width: 120, alignment: .leading)
                .accessibilityIdentifier("wrapped-text")
        }
        .setSize(Size(width: 240, height: 240))
        .performLayout()

        let textNode = tester.findNodeByAccessibilityIdentifier("wrapped-text")

        #expect((textNode?.frame.height ?? 0) > 40)
    }
}
