import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaUtils
import Math

@MainActor
struct ShapeRenderingTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func graphicsContext_fillPath_recordsFillCommand() {
        var path = Path()
        path.addRect(Rect(x: 0, y: 0, width: 40, height: 20))

        let context = makeContext { context in
            context.fill(path, with: .red)
        }

        guard let command = context.getDrawCommands().first else {
            Issue.record("Expected draw command for filled path.")
            return
        }

        guard case let .drawPath(_, mode) = command else {
            Issue.record("Expected first command to be drawPath.")
            return
        }

        guard case let .fill(color) = mode else {
            Issue.record("Expected path drawing mode to be fill.")
            return
        }

        #expect(color == .red)
    }

    @Test
    func graphicsContext_strokePath_recordsStrokeCommand() {
        var path = Path()
        path.addRect(Rect(x: 0, y: 0, width: 30, height: 30))
        let style = StrokeStyle(lineWidth: 3)

        let context = makeContext { context in
            context.stroke(path, with: .blue, style: style)
        }

        guard let command = context.getDrawCommands().first else {
            Issue.record("Expected draw command for stroked path.")
            return
        }

        guard case let .drawPath(_, mode) = command else {
            Issue.record("Expected first command to be drawPath.")
            return
        }

        guard case let .stroke(color, recordedStyle) = mode else {
            Issue.record("Expected path drawing mode to be stroke.")
            return
        }

        #expect(color == .blue)
        #expect(recordedStyle == style)
    }

    @Test
    func tessellator_fillRectProducesTriangleGeometry() {
        var path = Path()
        path.addRect(Rect(x: 0, y: 0, width: 100, height: 60))

        let result = UITessellator().tessellatePathFill(
            path,
            color: .green,
            transform: .identity
        )

        #expect(result.vertices.count == 4)
        #expect(result.indices.count == 6)
        #expect(result.vertices.allSatisfy { $0.color == .green })
    }

    @Test
    func tessellator_strokeCirclePreservesColorAndLineWidth() {
        let path = CircleShape().path(in: Rect(x: 0, y: 0, width: 40, height: 40))

        let result = UITessellator().tessellatePathStroke(
            path,
            lineWidth: 3,
            color: .mint,
            transform: .identity
        )

        #expect(!result.vertices.isEmpty)
        #expect(!result.indices.isEmpty)
        #expect(result.vertices.allSatisfy { $0.color == .mint && $0.lineWidth == 3 })
    }

    @Test
    func filledRectangleViewProducesFillPathCommand() {
        let mode = renderMode(for: RectangleShape().fill(Color.red))

        guard case let .fill(color)? = mode else {
            Issue.record("Expected rendered shape to use fill mode.")
            return
        }

        #expect(color == .red)
    }

    @Test
    func strokedCircleViewProducesStrokePathCommand() {
        let mode = renderMode(for: CircleShape().stroke(Color.blue, lineWidth: 3))

        guard case let .stroke(color, style)? = mode else {
            Issue.record("Expected rendered shape to use stroke mode.")
            return
        }

        #expect(color == .blue)
        #expect(style.lineWidth == 3)
    }

    private func makeContext(
        _ configure: (inout UIGraphicsContext) -> Void
    ) -> UIGraphicsContext {
        var context = UIGraphicsContext()
        configure(&context)
        return context
    }

    private func renderMode<Content: View>(
        for rootView: Content
    ) -> UIGraphicsContext.PathDrawingMode? {
        let tester = ViewTester(rootView: rootView)
            .setSize(Size(width: 120, height: 120))
            .performLayout()

        let context = UIGraphicsContext()
        tester.containerView.draw(
            in: Rect(origin: .zero, size: tester.containerView.frame.size),
            with: context
        )

        for command in context.getDrawCommands() {
            if case let .drawPath(_, mode) = command {
                return mode
            }
        }

        return nil
    }
}
