import AdaAnimation
import Math

/// A container that positions children within the available space without fixed pixel coordinates.
/// Children without ``View/relativePosition(x:y:)`` are centered. Child sizes follow normal AdaUI proposals.
public struct FreeLayout<Content: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("Unreachable code") }

    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let node = LayoutViewContainerNode(layout: FreePositionLayout(), content: view.value.content)
        node.updateEnvironment(inputs.environment)
        node.invalidateContent()
        return _ViewOutputs(node: node)
    }
}

struct FreePositionLayout: Layout {
    typealias AnimatableData = EmptyAnimatableData

    func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> Size {
        let ideal = subviews.reduce(Size.zero) { size, child in
            let measured = child.sizeThatFits(proposal)
            return Size(width: max(size.width, measured.width), height: max(size.height, measured.height))
        }
        return Size(
            width: proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? ideal.width,
            height: proposal.height.flatMap { $0.isFinite ? max(0, $0) : nil } ?? ideal.height
        )
    }

    func placeSubviews(in bounds: Rect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let proposal = ProposedViewSize(bounds.size)
        for child in subviews {
            let size = child.sizeThatFits(proposal)
            let position = child.node.relativeLayoutPosition ?? Point(0.5, 0.5)
            child.place(
                at: Point(bounds.minX + position.x * max(0, bounds.width - size.width), bounds.minY + position.y * max(0, bounds.height - size.height)),
                anchor: .topLeading,
                proposal: proposal
            )
        }
    }
}
