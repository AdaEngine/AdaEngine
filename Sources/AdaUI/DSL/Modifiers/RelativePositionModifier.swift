import Math

extension View {
    /// Positions a direct child of ``FreeLayout`` within the space left after measuring its size.
    /// Zero aligns the leading/top edges and one aligns the trailing/bottom edges. Other layouts ignore this value.
    /// Values are clamped to 0...1; nonfinite values use the center. This does not resize the view.
    public func relativePosition(x: Float, y: Float) -> some View {
        modifier(RelativePositionModifier(content: self, position: Point(
            x.isFinite ? min(1, max(0, x)) : 0.5,
            y.isFinite ? min(1, max(0, y)) : 0.5
        )))
    }
}

struct RelativePositionModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never
    let content: Content
    let position: Point

    func buildViewNode(in context: BuildContext) -> ViewNode {
        RelativePositionNode(position: position, contentNode: context.makeNode(from: content), content: content)
    }
}

final class RelativePositionNode: ViewModifierNode {
    private var position: Point
    override var relativeLayoutPosition: Point? { position }

    init<Content: View>(position: Point, contentNode: ViewNode, content: Content) {
        self.position = position
        super.init(contentNode: contentNode, content: content)
    }

    override func update(from newNode: ViewNode) {
        if let other = newNode as? RelativePositionNode, position != other.position {
            Self.recordLayoutMutationRequiringAncestorPass()
            position = other.position
        }
        super.update(from: newNode)
    }
}
