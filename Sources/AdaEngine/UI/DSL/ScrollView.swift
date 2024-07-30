//
//  ScrollView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

/// A scrollable view.
@MainActor @preconcurrency
public struct ScrollView<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let axis: Axis
    let content: () -> Content

    public init(
        _ axis: Axis = .vertical,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axis = axis
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = ScrollViewNode(layout: context.layout, content: content)
        node.axis = self.axis
        node.updateEnvironment(context.environment)
        context.environment.scrollViewProxy?.subsribe(node)
        node.invalidateContent()

        return node
    }
}

// FIXME: Hit test doesn't work correctly on bottom

final class ScrollViewNode: LayoutViewContainerNode {
    var axis: Axis = .vertical

    private(set) var contentOffset: Point = .zero
    private var contentSize: Size = .zero

    override func performLayout() {
        let proposal = ProposedViewSize(frame.size)
        self.contentSize = super.sizeThatFits(proposal)

        let width = contentSize.width - frame.width
        let height = contentSize.height - frame.height
        self.contentOffsetBounds = Rect(x: 0, y: 0, width: width, height: height)

        super.performLayout()
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        if let mouseEvent = event as? MouseEvent, mouseEvent.button == .scrollWheel {
            return self
        }

        return super.hitTest(point, with: event)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }

    enum State {
        case idle
        case dragging(initialOffset: Point)
    }

    private var accumulativePoint: Point = .zero
    private var state: State = .idle

    static let normalDecelerationRate: Float = 0.998
    static let fastDecelerationRate: Float = 0.99
    static let scrollTimeout: Float = 0.05

    private var lastScrollEvent: TimeInterval?

    override func onMouseEvent(_ event: MouseEvent) {
        guard event.button == .scrollWheel else {
            return
        }

        /// That a new scroll phase
        if let lastScrollEvent, event.time > lastScrollEvent + Self.scrollTimeout {
            self.lastScrollEvent = nil
            self.state = .idle
        }

        if self.lastScrollEvent == nil {
            /// If we don't have scroll time, that new scroll phase is began
            accumulativePoint = .zero
            state = .dragging(initialOffset: self.contentOffset)
            lastScrollEvent = event.time
            return
        }

        /// Scroll phase did update
        self.accumulativePoint.x += event.scrollDelta.x * 100
        self.accumulativePoint.y += event.scrollDelta.y * 100
        if case .dragging(let initialOffset) = state {
//            print("initial:", initialOffset, "point:", accumulativePoint, "res:", initialOffset - accumulativePoint)
            contentOffset = clampOffset(initialOffset - accumulativePoint)
        }
    }

    func project(initialVelocity: Float, decelerationRate: Float) -> Float {
        return (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }

    private var contentOffsetBounds: Rect = .zero

    private func clampOffset(_ offset: Point) -> Point {
        return offset.clamped(to: contentOffsetBounds)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: contentOffset.x, y: contentOffset.y)
        super.draw(with: context)
    }

    func scrollToViewNodeIfFoundIt(_ id: AnyHashable, anchor: AnchorPoint? = nil) {
        guard let foundedNode = self.findNodeById(id) else {
            return
        }

        let anchor = anchor ?? .zero
        let position = foundedNode.convert(foundedNode.frame.origin, to: self)

        let offset = Point(
            x: position.x - contentSize.width * anchor.x,
            y: position.y - contentSize.height * anchor.y
        )

        if axis == .vertical {
            self.contentOffset.y = clampOffset(offset).y
        } else {
            self.contentOffset.x = clampOffset(offset).x
        }
    }
}
