//
//  NavigationStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 25.03.2026.
//

import AdaInput
import AdaUtils
import Math

// MARK: - NavigationContext

/// Shared mutable navigation state owned by a single NavigationStack.
/// Passed through the environment so descendants can push/pop/register destinations.
@MainActor
final class NavigationContext {
    private(set) var path: NavigationPath
    private var destinationBuilders: [ObjectIdentifier: (AnyHashable, _ViewInputs) -> ViewNode?] = [:]
    var onPathChanged: (() -> Void)?

    init(path: NavigationPath) {
        self.path = path
    }

    func push(_ value: AnyHashable) {
        path.append(value)
        onPathChanged?()
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
        onPathChanged?()
    }

    func registerDestination<D: Hashable>(
        for type: D.Type,
        builder: @escaping (D, _ViewInputs) -> ViewNode
    ) {
        destinationBuilders[ObjectIdentifier(type)] = { anyValue, inputs in
            guard let typedValue = anyValue.base as? D else { return nil }
            return builder(typedValue, inputs)
        }
    }

    func buildDestination(for value: AnyHashable, inputs: _ViewInputs) -> ViewNode? {
        for builder in destinationBuilders.values {
            if let node = builder(value, inputs) {
                return node
            }
        }
        return nil
    }
}

extension EnvironmentValues {
    @Entry internal(set) var navigationContext: NavigationContext? = nil
}

// MARK: - NavigationStack View

/// A view that displays a root view and enables you to present additional views over the root view.
///
/// Use `.navigate(for:destination:)` on child views to register destinations.
///
/// ```swift
/// NavigationStack {
///     ContentView()
///         .navigate(for: String.self) { value in
///             DetailView(id: value)
///         }
/// }
/// ```
@MainActor @preconcurrency
public struct NavigationStack<Content: View>: View, ViewNodeBuilder {
    public typealias Body = Never
    public var body: Never { fatalError() }

    let pathBinding: Binding<NavigationPath>
    let content: () -> Content

    /// Creates a navigation stack with a bound path.
    public init(path: Binding<NavigationPath>, @ViewBuilder content: @escaping () -> Content) {
        self.pathBinding = path
        self.content = content
    }

    /// Creates a navigation stack with internal path state.
    public init(@ViewBuilder content: @escaping () -> Content) {
        var localPath = NavigationPath()
        self.pathBinding = Binding(
            get: { localPath },
            set: { localPath = $0 }
        )
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let navContext = NavigationContext(path: pathBinding.wrappedValue)
        let node = NavigationStackNode(
            inputs: context,
            pathBinding: pathBinding,
            navigationContext: navContext,
            contentBuilder: { inputs in
                let view = content()
                return Content._makeView(_ViewGraphNode(value: view), inputs: inputs).node
            }
        )
        navContext.onPathChanged = { [weak node] in
            node?.rebuildContent()
        }
        return node
    }
}

// MARK: - NavigationStackNode

final class NavigationStackNode: ViewNode {

    private var pathBinding: Binding<NavigationPath>
    private(set) var navigationContext: NavigationContext
    private var viewInputs: _ViewInputs
    private let contentBuilder: (_ViewInputs) -> ViewNode
    private var currentContentNode: ViewNode

    private var dismissAction: DismissAction {
        DismissAction { [weak self] in
            self?.navigationContext.pop()
        }
    }

    init(
        inputs: _ViewInputs,
        pathBinding: Binding<NavigationPath>,
        navigationContext: NavigationContext,
        contentBuilder: @escaping (_ViewInputs) -> ViewNode
    ) {
        self.pathBinding = pathBinding
        self.navigationContext = navigationContext
        self.viewInputs = inputs
        self.contentBuilder = contentBuilder

        // Always build root first so .navigate(for:) modifiers register destinations.
        let childInputs = Self.makeChildInputs(from: inputs, context: navigationContext)
        self.currentContentNode = contentBuilder(childInputs)

        super.init(content: AnyView(EmptyView()))
        currentContentNode.parent = self

        // If the path already has values (e.g. binding was pre-populated),
        // switch to the appropriate destination now that it's been registered.
        if !navigationContext.path.isEmpty {
            rebuildContent()
        }
    }

    func rebuildContent() {
        let childInputs = Self.makeChildInputs(
            from: viewInputs,
            context: navigationContext,
            dismiss: dismissAction
        )

        let newNode: ViewNode
        if let topValue = navigationContext.path.topElement,
           let destNode = navigationContext.buildDestination(for: topValue, inputs: childInputs) {
            newNode = destNode
        } else {
            newNode = contentBuilder(childInputs)
        }

        if newNode.canUpdate(currentContentNode) {
            currentContentNode.update(from: newNode)
        } else {
            currentContentNode.parent = nil
            currentContentNode = newNode
            currentContentNode.parent = self

            if let owner {
                currentContentNode.updateViewOwner(owner)
            }
        }

        currentContentNode.updateEnvironment(childInputs.environment)
        invalidateNearestLayer()
        owner?.containerView?.setNeedsDisplay(in: absoluteFrame())
        performLayout()

        pathBinding.wrappedValue = navigationContext.path
    }

    private static func makeChildInputs(
        from inputs: _ViewInputs,
        context: NavigationContext,
        dismiss: DismissAction? = nil
    ) -> _ViewInputs {
        var childInputs = inputs
        childInputs.environment.navigationContext = context
        if let dismiss {
            childInputs.environment.dismiss = dismiss
        }
        return childInputs
    }

    // MARK: - ViewNode overrides

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        currentContentNode.sizeThatFits(proposal)
    }

    override func performLayout() {
        let proposal = ProposedViewSize(frame.size)
        currentContentNode.place(
            in: Point(x: frame.width * 0.5, y: frame.height * 0.5),
            anchor: .center,
            proposal: proposal
        )
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        super.updateEnvironment(environment)
        viewInputs.environment = environment
        var childEnv = environment
        childEnv.navigationContext = navigationContext
        childEnv.dismiss = dismissAction
        currentContentNode.updateEnvironment(childEnv)
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        currentContentNode.updateViewOwner(owner)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }
        let newPoint = currentContentNode.convert(point, from: self)
        return currentContentNode.hitTest(newPoint, with: event)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)
        currentContentNode.draw(with: context)
    }

    override func update(_ deltaTime: TimeInterval) {
        currentContentNode.update(deltaTime)
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        currentContentNode.findNodeById(id)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        super.findNodyByAccessibilityIdentifier(identifier)
            ?? currentContentNode.findNodyByAccessibilityIdentifier(identifier)
    }

    override func invalidateContent() {
        rebuildContent()
    }

    override func didMove(to parent: ViewNode?) {
        super.didMove(to: parent)
        if parent == nil {
            currentContentNode.parent = nil
        }
    }

    override func onMouseEvent(_ event: MouseEvent) {
        currentContentNode.onMouseEvent(event)
    }

    override func onReceiveEvent(_ event: any InputEvent) {
        currentContentNode.onReceiveEvent(event)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        currentContentNode.onTouchesEvent(touches)
    }
}
