//
//  FullScreenCoverModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 25.03.2026.
//

import AdaInput
import AdaUtils
import Math

public extension View {
    /// Presents a modal view that covers as much of the screen as possible.
    ///
    /// The presented view can be dismissed via the ``DismissAction`` from the environment.
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State var showModal = false
    ///
    ///     var body: some View {
    ///         Button("Open") { showModal = true }
    ///             .fullScreenCover(isPresented: $showModal) {
    ///                 ModalView()
    ///             }
    ///     }
    /// }
    /// ```
    func fullScreenCover<Overlay: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Overlay
    ) -> some View {
        modifier(FullScreenCoverModifier(content: self, isPresented: isPresented, overlay: content))
    }
}

struct FullScreenCoverModifier<WrappedContent: View, Overlay: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: WrappedContent
    let isPresented: Binding<Bool>
    let overlay: () -> Overlay

    func buildViewNode(in context: BuildContext) -> ViewNode {
        FullScreenCoverNode(
            contentNode: context.makeNode(from: content),
            content: content,
            isPresented: isPresented,
            overlayBuilder: { inputs in
                let view = overlay()
                return Overlay._makeView(_ViewGraphNode(value: view), inputs: inputs).node
            },
            inputs: context
        )
    }
}

// MARK: - FullScreenCoverNode

final class FullScreenCoverNode: ViewModifierNode {

    private var isPresented: Binding<Bool>
    private let overlayBuilder: (_ViewInputs) -> ViewNode
    private var overlayNode: ViewNode?
    private var viewInputs: _ViewInputs

    init<Content: View>(
        contentNode: ViewNode,
        content: Content,
        isPresented: Binding<Bool>,
        overlayBuilder: @escaping (_ViewInputs) -> ViewNode,
        inputs: _ViewInputs
    ) {
        self.isPresented = isPresented
        self.overlayBuilder = overlayBuilder
        self.viewInputs = inputs
        super.init(contentNode: contentNode, content: content)
        rebuildOverlay()
    }

    private func rebuildOverlay() {
        if isPresented.wrappedValue {
            let dismissAction = DismissAction { [weak self] in
                self?.isPresented.wrappedValue = false
                self?.rebuildOverlay()
            }
            var inputs = viewInputs
            inputs.environment.dismiss = dismissAction
            let node = overlayBuilder(inputs)
            node.parent = self
            if let owner {
                node.updateViewOwner(owner)
            }
            node.updateEnvironment(inputs.environment)
            overlayNode = node
        } else {
            overlayNode?.parent = nil
            overlayNode = nil
        }

        invalidateNearestLayer()
        owner?.containerView?.setNeedsDisplay(in: absoluteFrame())
        performLayout()
    }

    override func performLayout() {
        let proposal = ProposedViewSize(frame.size)
        let origin = Point(x: frame.width * 0.5, y: frame.height * 0.5)

        contentNode.place(in: origin, anchor: .center, proposal: proposal)

        if let overlayNode {
            overlayNode.place(in: origin, anchor: .center, proposal: proposal)
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        contentNode.sizeThatFits(proposal)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        guard self.environment.version != prevVersion else { return }
        viewInputs.environment = self.environment

        if var overlayNode {
            var overlayEnv = self.environment
            overlayEnv.dismiss = DismissAction { [weak self] in
                self?.isPresented.wrappedValue = false
                self?.rebuildOverlay()
            }
            overlayNode.updateEnvironment(overlayEnv)
        }
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        overlayNode?.updateViewOwner(owner)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)
        contentNode.draw(with: context)
        overlayNode?.draw(with: context)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }

        if let overlayNode {
            let overlayPoint = overlayNode.convert(point, from: self)
            if let hit = overlayNode.hitTest(overlayPoint, with: event) {
                return hit
            }
        }

        let contentPoint = contentNode.convert(point, from: self)
        return contentNode.hitTest(contentPoint, with: event)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? FullScreenCoverNode else { return }
        self.isPresented = other.isPresented
        rebuildOverlay()
    }

    override func update(_ deltaTime: TimeInterval) {
        super.update(deltaTime)
        overlayNode?.update(deltaTime)
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        overlayNode?.findNodeById(id) ?? super.findNodeById(id)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        overlayNode?.findNodyByAccessibilityIdentifier(identifier) ?? super.findNodyByAccessibilityIdentifier(identifier)
    }

    override func didMove(to parent: ViewNode?) {
        super.didMove(to: parent)
        if parent == nil {
            overlayNode?.parent = nil
        }
    }
}
