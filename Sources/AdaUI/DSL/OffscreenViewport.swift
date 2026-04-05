//
//  OffscreenViewport.swift
//  AdaEngine
//
//  Created by AdaEngine on 04.04.2026.
//

@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import AdaUtils
import Math

// MARK: - Delegate Protocol

@MainActor
package protocol OffscreenViewportDelegate: AnyObject {
    var renderTexture: Texture2D? { get }
    func bootstrapIfNeeded()
    func tick(_ deltaTime: AdaUtils.TimeInterval)
    func receiveInputEvent(_ event: any InputEvent)
    func updateMousePosition(_ position: Point)
    func updateSize(_ size: SizeInt, scaleFactor: Float)
}

// MARK: - Viewport View

package struct OffscreenViewportView: View, ViewNodeBuilder {
    package typealias Body = Never

    let delegate: any OffscreenViewportDelegate

    package init(delegate: any OffscreenViewportDelegate) {
        self.delegate = delegate
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        OffscreenViewportNode(delegate: delegate, content: self)
    }
}

// MARK: - Container View

package struct OffscreenViewportContainer<Content: View>: View, ViewNodeBuilder {
    package typealias Body = Never

    let delegateFactory: @MainActor () -> any OffscreenViewportDelegate
    let contentBuilder: @MainActor (any OffscreenViewportDelegate) -> Content

    package init(
        delegateFactory: @escaping @MainActor () -> any OffscreenViewportDelegate,
        @ViewBuilder contentBuilder: @escaping @MainActor (any OffscreenViewportDelegate) -> Content
    ) {
        self.delegateFactory = delegateFactory
        self.contentBuilder = contentBuilder
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        OffscreenViewportContainerNode(
            delegateFactory: delegateFactory,
            contentBuilder: contentBuilder,
            content: self
        )
    }
}

// MARK: - Viewport ViewNode

@MainActor
private final class OffscreenViewportNode: ViewNode {

    private let delegate: any OffscreenViewportDelegate
    private var lastReportedSize: SizeInt = .zero
    private var isActive = false
    private var didBootstrap = false

    private static weak var currentActiveViewport: OffscreenViewportNode?

    init<C: View>(delegate: any OffscreenViewportDelegate, content: C) {
        self.delegate = delegate
        super.init(content: content)
    }

    // MARK: Layout

    override func performLayout() {
        super.performLayout()

        if !didBootstrap {
            didBootstrap = true
            delegate.bootstrapIfNeeded()
        }

        let size = frame.size
        let scale = max(environment.scaleFactor, 1)
        let pixelSize = SizeInt(
            width: Int(size.width * scale),
            height: Int(size.height * scale)
        )

        guard pixelSize.width > 0 && pixelSize.height > 0 else { return }

        if pixelSize != lastReportedSize {
            lastReportedSize = pixelSize
            delegate.updateSize(pixelSize, scaleFactor: scale)
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }

    // MARK: Tick

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        delegate.tick(deltaTime)
    }

    // MARK: Draw

    override func draw(with context: UIGraphicsContext) {
        guard let texture = delegate.renderTexture else {
            super.draw(with: context)
            return
        }

        var context = context
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        let rect = Rect(origin: .zero, size: frame.size)
        context.drawRect(rect, texture: texture, color: .white)
    }

    // MARK: Input

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }
        return self
    }

    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        let size = frame.size
        return point.x >= 0 && point.y >= 0 && point.x <= size.width && point.y <= size.height
    }

    override func onMouseEvent(_ event: MouseEvent) {
        let localPosition = viewportLocalPosition(event.mousePosition)
        let localEvent = MouseEvent(
            window: event.window,
            button: event.button,
            scrollDelta: event.scrollDelta,
            mousePosition: localPosition,
            phase: event.phase,
            modifierKeys: event.modifierKeys,
            time: event.time
        )

        if event.phase == .began {
            activateViewport()
        }

        delegate.updateMousePosition(localPosition)
        delegate.receiveInputEvent(localEvent)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        if touches.contains(where: { $0.phase == .began }) {
            activateViewport()
        }

        for touch in touches {
            let localPosition = viewportLocalPosition(touch.location)
            let localTouch = TouchEvent(
                window: touch.window,
                location: localPosition,
                phase: touch.phase,
                time: touch.time
            )
            delegate.receiveInputEvent(localTouch)
        }
    }

    override func onKeyEvent(_ event: KeyEvent) {
        guard isActive else { return }
        delegate.receiveInputEvent(event)
    }

    override func onTextInputEvent(_ event: TextInputEvent) {
        guard isActive else { return }
        delegate.receiveInputEvent(event)
    }

    override var canBecomeFocused: Bool { true }

    override func onFocusChanged(isFocused: Bool) {
        if !isFocused && isActive {
            isActive = false
        }
    }

    // MARK: Private

    private func viewportLocalPosition(_ windowPosition: Point) -> Point {
        let absoluteOrigin = absoluteFrame().origin
        return Point(
            x: windowPosition.x - absoluteOrigin.x,
            y: windowPosition.y - absoluteOrigin.y
        )
    }

    private func activateViewport() {
        if let previous = Self.currentActiveViewport, previous !== self {
            previous.isActive = false
        }
        isActive = true
        Self.currentActiveViewport = self
    }
}

// MARK: - Container ViewNode

@MainActor
private final class OffscreenViewportContainerNode<Content: View>: ViewContainerNode {

    private var delegate: (any OffscreenViewportDelegate)?
    private let delegateFactory: @MainActor () -> any OffscreenViewportDelegate
    private let contentBuilder: @MainActor (any OffscreenViewportDelegate) -> Content

    init<Root: View>(
        delegateFactory: @escaping @MainActor () -> any OffscreenViewportDelegate,
        contentBuilder: @escaping @MainActor (any OffscreenViewportDelegate) -> Content,
        content: Root
    ) {
        self.delegateFactory = delegateFactory
        self.contentBuilder = contentBuilder
        super.init(content: content, body: { _ in fatalError() })
    }

    override func invalidateContent() {
        if delegate == nil {
            delegate = delegateFactory()
        }

        let view = contentBuilder(delegate!)
        let inputs = _ViewInputs(parentNode: self, environment: self.environment)
        let outputs = Content._makeListView(
            _ViewGraphNode(value: view),
            inputs: _ViewListInputs(input: inputs)
        ).outputs
        let nodes = outputs.map { $0.node }

        for node in nodes {
            node.parent = self
        }

        self.nodes = nodes
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let other = newNode as? OffscreenViewportContainerNode<Content> else {
            return
        }
        self.updateChildNodes(from: other.nodes)
    }

    private func updateChildNodes(from newNodes: [ViewNode]) {
        for node in newNodes {
            node.parent = self
        }
        self.nodes = newNodes
        self.performLayout()
    }
}
