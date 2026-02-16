//
//  ScrollView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import AdaInput
import AdaUtils
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
        let node = ScrollViewNode(layout: ZStackLayout(anchor: .topLeading), content: content)
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
        let viewportSize = self.frame.size
        let proposedWidth: Float? = axis.contains(.horizontal) ? nil : viewportSize.width
        let proposedHeight: Float? = axis.contains(.vertical) ? nil : viewportSize.height
        let proposal = ProposedViewSize(width: proposedWidth, height: proposedHeight)
        let measuredContentSize = super.sizeThatFits(proposal)

        let measuredWidth = measuredContentSize.width.isFinite ? measuredContentSize.width : viewportSize.width
        let measuredHeight = measuredContentSize.height.isFinite ? measuredContentSize.height : viewportSize.height

        let contentWidth = axis.contains(.horizontal) ? max(measuredWidth, viewportSize.width) : viewportSize.width
        let contentHeight = axis.contains(.vertical) ? max(measuredHeight, viewportSize.height) : viewportSize.height
        self.contentSize = Size(width: contentWidth, height: contentHeight)

        let width = max(0, contentSize.width - viewportSize.width)
        let height = max(0, contentSize.height - viewportSize.height)
        self.contentOffsetBounds = Rect(x: 0, y: 0, width: width, height: height)
        self.contentOffset = clampOffset(self.contentOffset)
        super.performLayout(
            in: Rect(origin: .zero, size: contentSize),
            proposal: ProposedViewSize(contentSize)
        )
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        if let mouseEvent = event as? MouseEvent, mouseEvent.button == .scrollWheel {
            return self
        }

        let contentPoint = Point(
            x: point.x + contentOffset.x,
            y: point.y + contentOffset.y
        )
        return super.hitTest(contentPoint, with: event)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if proposal == .zero {
            return .zero
        }

        let proposedWidth = finiteDimension(proposal.width)
        let proposedHeight = finiteDimension(proposal.height)
        let contentProposal = ProposedViewSize(
            width: axis.contains(.horizontal) ? nil : proposedWidth,
            height: axis.contains(.vertical) ? nil : proposedHeight
        )
        let measuredContentSize = super.sizeThatFits(contentProposal)

        let width = resolvedDimension(
            proposed: proposal.width,
            measured: measuredContentSize.width
        )
        let height = resolvedDimension(
            proposed: proposal.height,
            measured: measuredContentSize.height
        )

        return Size(width: max(0, width), height: max(0, height))
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
            setContentOffset(clampOffset(initialOffset - accumulativePoint))
        }
    }

    func project(initialVelocity: Float, decelerationRate: Float) -> Float {
        return (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }

    private var contentOffsetBounds: Rect = .zero

    private func clampOffset(_ offset: Point) -> Point {
        var clamped = self.contentOffset
        if axis.contains(.vertical) {
            clamped.y = clamp(offset.y, contentOffsetBounds.minY, contentOffsetBounds.maxY)
        }

        if axis.contains(.horizontal) {
            clamped.x = clamp(offset.x, contentOffsetBounds.minX, contentOffsetBounds.maxX)
        }

        return clamped
    }

    private func setContentOffset(_ newValue: Point) {
        guard contentOffset != newValue else {
            return
        }

        contentOffset = newValue
        self.invalidateNearestLayer()
        if let containerView = self.owner?.containerView {
            containerView.setNeedsDisplay(in: self.absoluteFrame())
        }
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.pushClipRect(self.absoluteFrame())
        context.translateBy(x: -contentOffset.x, y: -contentOffset.y)
        super.draw(with: context)
        context.popClipRect()
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

        let clampedOffset = clampOffset(offset)
        setContentOffset(clampedOffset)
    }

    @inline(__always)
    private func finiteDimension(_ value: Float?) -> Float? {
        guard let value, value.isFinite else {
            return nil
        }

        return value
    }

    @inline(__always)
    private func resolvedDimension(proposed: Float?, measured: Float) -> Float {
        if proposed == .infinity {
            return .infinity
        }

        if let proposed, proposed.isFinite {
            return proposed
        }

        return measured.isFinite ? measured : 0
    }
}
