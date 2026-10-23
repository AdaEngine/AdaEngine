@_spi(Internal) @testable import AdaUI
import Math
import Testing

@MainActor
@Suite("Synchronous Canvas drawing revisions")
struct CanvasRevisionTests {
    @Test("Revision changes refresh retained commands without layout or async observation")
    func revisionRefreshesDrawing() throws {
        var revision: UInt64 = 0
        var draws = 0
        let container = UIContainerView(rootView: Canvas(drawingRevision: { revision }) { context, _ in
            draws += 1
            context.drawRect(Rect(x: Float(revision), y: 0, width: 10, height: 10), color: .red)
        })
        container.frame = Rect(x: 0, y: 0, width: 200, height: 100)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()

        func draw() throws -> (UInt64, Transform3D) {
            let context = UIGraphicsContext()
            container.viewTree.rootNode.draw(with: context)
            context.commitDraw()
            let commands = context.getDrawCommands()
            let version = try #require(commands.compactMap { command -> UInt64? in
                if case let .beginLayer(_, version, true) = command { return version }
                return nil
            }.first)
            let transform = try #require(commands.compactMap { command -> Transform3D? in
                if case let .drawQuad(transform, _, _) = command { return transform }
                return nil
            }.first)
            return (version, transform)
        }

        let first = try draw()
        #expect(try draw().0 == first.0)
        #expect(draws == 1)
        revision = 50
        let second = try draw()
        #expect(second.0 > first.0)
        #expect(second.1.origin.x - first.1.origin.x == 50)
        #expect(draws == 2)
        #expect(try draw().0 == second.0)
        #expect(draws == 2)

        container.frame.size = Size(width: 300, height: 150)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        #expect(try draw().0 > second.0)
        #expect(draws == 3)
    }
}
