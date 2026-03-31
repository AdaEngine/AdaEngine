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
        if case .idle = state {
            self.contentOffset = clampOffset(self.contentOffset)
        }

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

        if let childHit = super.hitTest(contentPoint, with: event) {
            return childHit
        }

        // For touch events, claim the hit ourselves so drag-to-scroll works
        if event is TouchEvent {
            return self
        }

        return nil
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
            measured: measuredContentSize.width,
            isScrollAxis: axis.contains(.horizontal)
        )
        let height = resolvedDimension(
            proposed: proposal.height,
            measured: measuredContentSize.height,
            isScrollAxis: axis.contains(.vertical)
        )

        return Size(width: max(0, width), height: max(0, height))
    }

    enum State {
        case idle
        case dragging(initialOffset: Point)
        case animating
    }

    private var accumulativePoint: Point = .zero
    private var state: State = .idle
    private var velocity: Point = .zero
    private var velocityTracker: [(time: TimeInterval, position: Point)] = []
    private var timeSinceLastScroll: Float = 0

    static let decelerationFriction: Float = 2.0
    static let scrollTimeout: Float = 0.05
    static let springStiffness: Float = 400
    static let springDamping: Float = 40
    static let rubberBandCoefficient: Float = 0.35
    static let animationThreshold: Float = 0.5

    private var lastScrollEvent: TimeInterval?

    override func onMouseEvent(_ event: MouseEvent) {
        guard event.button == .scrollWheel else {
            return
        }

        let isNewPhase: Bool
        if let lastScroll = lastScrollEvent {
            isNewPhase = event.time > lastScroll + Self.scrollTimeout
        } else {
            isNewPhase = true
        }

        timeSinceLastScroll = 0
        lastScrollEvent = event.time

        if isNewPhase {
            accumulativePoint = .zero
            velocity = .zero
            state = .dragging(initialOffset: self.contentOffset)
            return
        }

        self.accumulativePoint.x += event.scrollDelta.x * 100
        self.accumulativePoint.y += event.scrollDelta.y * 100
        if case .dragging(let initialOffset) = state {
            setContentOffset(rubberBandOffset(initialOffset - accumulativePoint))
        }
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        guard let touch = touches.first else { return }

        switch touch.phase {
        case .began:
            velocity = .zero
            lastScrollEvent = nil
            timeSinceLastScroll = 0
            accumulativePoint = .zero
            velocityTracker = []
            state = .dragging(initialOffset: self.contentOffset)
        case .moved:
            guard case .dragging(let initialOffset) = state else { return }
            accumulativePoint.x += touch.location.x - (lastTouchLocation?.x ?? touch.location.x)
            accumulativePoint.y += touch.location.y - (lastTouchLocation?.y ?? touch.location.y)
            let rawOffset = Point(
                x: initialOffset.x - accumulativePoint.x,
                y: initialOffset.y - accumulativePoint.y
            )
            setContentOffset(rubberBandOffset(rawOffset))

            velocityTracker.append((time: touch.time, position: touch.location))
            if velocityTracker.count > 5 {
                velocityTracker.removeFirst()
            }
        case .ended, .cancelled:
            let releaseVelocity = calculateReleaseVelocity()
            let overscroll = calculateOverscroll(contentOffset)

            if overscroll != .zero || (releaseVelocity.x * releaseVelocity.x + releaseVelocity.y * releaseVelocity.y) > 1 {
                velocity = releaseVelocity
                state = .animating
            } else {
                state = .idle
            }

            accumulativePoint = .zero
            velocityTracker = []
        }

        lastTouchLocation = touch.location
        if touch.phase == .ended || touch.phase == .cancelled {
            lastTouchLocation = nil
        }
    }

    private var lastTouchLocation: Point?

    // MARK: - Bounce Animation

    override func update(_ deltaTime: TimeInterval) {
        super.update(deltaTime)

        if lastScrollEvent != nil, case .dragging = state {
            timeSinceLastScroll += deltaTime
            if timeSinceLastScroll >= Self.scrollTimeout {
                lastScrollEvent = nil
                timeSinceLastScroll = 0
                if calculateOverscroll(contentOffset) != .zero {
                    velocity = .zero
                    state = .animating
                } else {
                    state = .idle
                }
            }
        }

        guard case .animating = state, deltaTime > 0 else { return }

        var newOffset = contentOffset
        var finished = true

        if axis.contains(.vertical) {
            if !updateBounceAxis(
                offset: &newOffset.y,
                velocity: &velocity.y,
                minBound: contentOffsetBounds.minY,
                maxBound: contentOffsetBounds.maxY,
                dimension: frame.size.height,
                dt: deltaTime
            ) {
                finished = false
            }
        }

        if axis.contains(.horizontal) {
            if !updateBounceAxis(
                offset: &newOffset.x,
                velocity: &velocity.x,
                minBound: contentOffsetBounds.minX,
                maxBound: contentOffsetBounds.maxX,
                dimension: frame.size.width,
                dt: deltaTime
            ) {
                finished = false
            }
        }

        setContentOffset(newOffset)

        if finished {
            setContentOffset(clampOffset(contentOffset))
            velocity = .zero
            state = .idle
        }
    }

    private func updateBounceAxis(
        offset: inout Float,
        velocity: inout Float,
        minBound: Float,
        maxBound: Float,
        dimension: Float,
        dt: Float
    ) -> Bool {
        let overscroll: Float
        if offset < minBound {
            overscroll = offset - minBound
        } else if offset > maxBound {
            overscroll = offset - maxBound
        } else {
            overscroll = 0
        }

        if overscroll != 0 {
            let springForce = -Self.springStiffness * overscroll
            let dampingForce = -Self.springDamping * velocity
            velocity += (springForce + dampingForce) * dt
        } else {
            velocity *= max(0, 1 - Self.decelerationFriction * dt)
        }

        offset += velocity * dt

        let currentOverscroll: Float
        if offset < minBound {
            currentOverscroll = minBound - offset
        } else if offset > maxBound {
            currentOverscroll = offset - maxBound
        } else {
            currentOverscroll = 0
        }

        return abs(velocity) < Self.animationThreshold && currentOverscroll < Self.animationThreshold
    }

    // MARK: - Rubber Band

    private func rubberBandOffset(_ offset: Point) -> Point {
        var result = contentOffset
        if axis.contains(.vertical) {
            result.y = rubberBandClamp(
                offset.y,
                min: contentOffsetBounds.minY,
                max: contentOffsetBounds.maxY,
                dimension: frame.size.height
            )
        }
        if axis.contains(.horizontal) {
            result.x = rubberBandClamp(
                offset.x,
                min: contentOffsetBounds.minX,
                max: contentOffsetBounds.maxX,
                dimension: frame.size.width
            )
        }
        return result
    }

    private func rubberBandClamp(_ value: Float, min minBound: Float, max maxBound: Float, dimension: Float) -> Float {
        if value < minBound {
            return minBound - rubberBandDistance(minBound - value, dimension: dimension)
        } else if value > maxBound {
            return maxBound + rubberBandDistance(value - maxBound, dimension: dimension)
        }
        return value
    }

    @inline(__always)
    private func rubberBandDistance(_ distance: Float, dimension: Float) -> Float {
        guard dimension > 0 else { return 0 }
        let c = Self.rubberBandCoefficient
        return (1 - 1 / (distance * c / dimension + 1)) * dimension
    }

    // MARK: - Velocity Tracking

    private func calculateReleaseVelocity() -> Point {
        guard velocityTracker.count >= 2,
              let first = velocityTracker.first,
              let last = velocityTracker.last else {
            return .zero
        }
        let dt = last.time - first.time
        guard dt > 0.001 else { return .zero }
        return Point(
            x: axis.contains(.horizontal) ? -(last.position.x - first.position.x) / dt : 0,
            y: axis.contains(.vertical) ? -(last.position.y - first.position.y) / dt : 0
        )
    }

    private func calculateOverscroll(_ offset: Point) -> Point {
        var result = Point.zero
        if axis.contains(.vertical) {
            if offset.y < contentOffsetBounds.minY {
                result.y = offset.y - contentOffsetBounds.minY
            } else if offset.y > contentOffsetBounds.maxY {
                result.y = offset.y - contentOffsetBounds.maxY
            }
        }
        if axis.contains(.horizontal) {
            if offset.x < contentOffsetBounds.minX {
                result.x = offset.x - contentOffsetBounds.minX
            } else if offset.x > contentOffsetBounds.maxX {
                result.x = offset.x - contentOffsetBounds.maxX
            }
        }
        return result
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
        context.translateBy(x: -contentOffset.x, y: contentOffset.y)
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

    func scrollToNodeIfDescendant(_ node: ViewNode, anchor: AnchorPoint? = nil) -> Bool {
        guard self.containsDescendant(node) else {
            return false
        }

        let anchor = anchor ?? .zero
        let position = node.convert(node.frame.origin, to: self)
        let offset = Point(
            x: position.x - contentSize.width * anchor.x,
            y: position.y - contentSize.height * anchor.y
        )
        let clampedOffset = clampOffset(offset)
        setContentOffset(clampedOffset)
        return true
    }

    private func containsDescendant(_ node: ViewNode) -> Bool {
        var current: ViewNode? = node
        while let currentNode = current {
            if currentNode === self {
                return true
            }
            current = currentNode.parent
        }
        return false
    }

    @inline(__always)
    private func finiteDimension(_ value: Float?) -> Float? {
        guard let value, value.isFinite else {
            return nil
        }

        return value
    }

    @inline(__always)
    private func resolvedDimension(
        proposed: Float?,
        measured: Float,
        isScrollAxis: Bool
    ) -> Float {
        if proposed == .infinity {
            return .infinity
        }

        if let proposed, proposed.isFinite {
            return proposed
        }

        // ScrollView should not claim content size as "ideal" along scrolling axis.
        // Otherwise parent stacks size it to content and overflow becomes zero.
        if isScrollAxis {
            return 0
        }

        return measured.isFinite ? measured : 0
    }
}
