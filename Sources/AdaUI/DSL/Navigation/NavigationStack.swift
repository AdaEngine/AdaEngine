//
//  NavigationStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 25.03.2026.
//

import AdaInput
import AdaText
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
    @Entry internal var navigationBarConfiguration: NavigationBarConfiguration = NavigationBarConfiguration()
    @Entry internal var navigationBarLeadingItems: NavigationBarItemContent? = nil
    @Entry internal var navigationBarTrailingItems: NavigationBarItemContent? = nil
}

// MARK: - Navigation bar configuration

public enum NavigationTitlePosition: Hashable, Sendable {
    case automatic
    case leading
    case center
}

public enum NavigationBarTitleDisplayMode: Hashable, Sendable {
    case automatic
    case inline
    case large
}

struct NavigationBarConfiguration: Hashable, Sendable {
    var title: String?
    var titlePosition: NavigationTitlePosition = .automatic
    var titleDisplayMode: NavigationBarTitleDisplayMode = .automatic
    var backButtonHidden = false
}

final class NavigationBarItemContent: @unchecked Sendable {
    let makeNode: @MainActor (_ViewInputs) -> ViewNode

    @MainActor
    init<Content: View>(@ViewBuilder content: @MainActor @escaping () -> Content) {
        self.makeNode = { inputs in
            let view = content()
            return Content._makeView(_ViewGraphNode(value: view), inputs: inputs).node
        }
    }
}

public extension View {
    func navigationTitle(_ title: String) -> some View {
        self.transformEnvironment(\.navigationBarConfiguration) { configuration in
            configuration.title = title
        }
    }

    func navigationTitle(_ title: Text) -> some View {
        self.navigationTitle(title.plainText)
    }

    func navigationTitlePosition(_ position: NavigationTitlePosition) -> some View {
        self.transformEnvironment(\.navigationBarConfiguration) { configuration in
            configuration.titlePosition = position
        }
    }

    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self.transformEnvironment(\.navigationBarConfiguration) { configuration in
            configuration.titleDisplayMode = mode
        }
    }

    func navigationBarBackButtonHidden(_ hidden: Bool = true) -> some View {
        self.transformEnvironment(\.navigationBarConfiguration) { configuration in
            configuration.backButtonHidden = hidden
        }
    }

    func navigationBarLeadingItems<Content: View>(
        @ViewBuilder _ content: @MainActor @escaping () -> Content
    ) -> some View {
        self.environment(\.navigationBarLeadingItems, NavigationBarItemContent(content: content))
    }

    func navigationBarTrailingItems<Content: View>(
        @ViewBuilder _ content: @MainActor @escaping () -> Content
    ) -> some View {
        self.environment(\.navigationBarTrailingItems, NavigationBarItemContent(content: content))
    }

    func navigationBar<Content: View>(
        @ViewBuilder trailingItems: @MainActor @escaping () -> Content
    ) -> some View {
        self.navigationBarTrailingItems(trailingItems)
    }
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

    private enum Constants {
        static let navigationBarHeight: Float = 92
    }

    private var pathBinding: Binding<NavigationPath>
    private(set) var navigationContext: NavigationContext
    private var viewInputs: _ViewInputs
    private let contentBuilder: (_ViewInputs) -> ViewNode
    private var currentContentNode: ViewNode
    private var navigationBarNode: NavigationBarNode?
    private var reservedNavigationBarHeight: Float = 0

    private lazy var dismissAction = DismissAction { [weak self] in
        self?.navigationContext.pop()
    }

    /// Subtree searched for keyboard shortcut targets (matches visible stack content).
    var shortcutContentSubtree: ViewNode {
        currentContentNode
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
        syncNavigationBar()

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
        syncNavigationBar()
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

    private func makeContentInputs(reservingNavigationBarHeight height: Float) -> _ViewInputs {
        var inputs = Self.makeChildInputs(
            from: viewInputs,
            context: navigationContext,
            dismiss: dismissAction
        )
        if height > 0 {
            inputs.environment.safeAreaInsets.top += height
        }
        return inputs
    }

    private func syncNavigationBar() {
        let configuration = currentContentNode.environment.navigationBarConfiguration
        let showsBackButton = !navigationContext.path.isEmpty && !configuration.backButtonHidden
        let hasTitle = !(configuration.title?.isEmpty ?? true)
        let hasLeadingItems = currentContentNode.environment.navigationBarLeadingItems != nil
        let hasTrailingItems = currentContentNode.environment.navigationBarTrailingItems != nil
        let showsNavigationBar = hasTitle || showsBackButton || hasLeadingItems || hasTrailingItems

        let contentReceivesTopSafeArea = showsNavigationBar && Self.nodeConsumesTopSafeArea(currentContentNode)
        let contentSafeAreaHeight = contentReceivesTopSafeArea ? Constants.navigationBarHeight : 0
        reservedNavigationBarHeight = showsNavigationBar ? Constants.navigationBarHeight : 0

        let contentInputs = makeContentInputs(reservingNavigationBarHeight: contentSafeAreaHeight)
        currentContentNode.updateEnvironment(contentInputs.environment)

        guard showsNavigationBar else {
            navigationBarNode?.parent = nil
            navigationBarNode = nil
            return
        }

        var barInputs = Self.makeChildInputs(
            from: viewInputs,
            context: navigationContext,
            dismiss: dismissAction
        )
        barInputs.environment = currentContentNode.environment
        barInputs.environment.navigationContext = navigationContext
        barInputs.environment.dismiss = dismissAction

        if let navigationBarNode {
            navigationBarNode.update(
                configuration: configuration,
                leadingItems: currentContentNode.environment.navigationBarLeadingItems,
                trailingItems: currentContentNode.environment.navigationBarTrailingItems,
                showsBackButton: showsBackButton,
                inputs: barInputs
            )
        } else {
            let node = NavigationBarNode(
                configuration: configuration,
                leadingItems: currentContentNode.environment.navigationBarLeadingItems,
                trailingItems: currentContentNode.environment.navigationBarTrailingItems,
                showsBackButton: showsBackButton,
                navigationContext: navigationContext,
                inputs: barInputs
            )
            node.parent = self
            if let owner {
                node.updateViewOwner(owner)
            }
            navigationBarNode = node
        }
    }

    // MARK: - ViewNode overrides

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        currentContentNode.sizeThatFits(proposal)
    }

    override func performLayout() {
        let placesContentBelowBar = reservedNavigationBarHeight > 0 && !Self.nodeConsumesTopSafeArea(currentContentNode)
        let contentOriginY: Float = placesContentBelowBar ? reservedNavigationBarHeight : 0
        let contentSize = Size(
            width: frame.width,
            height: max(0, frame.height - contentOriginY)
        )
        let proposal = ProposedViewSize(contentSize)
        currentContentNode.place(
            in: Point(x: contentSize.width * 0.5, y: contentOriginY + contentSize.height * 0.5),
            anchor: .center,
            proposal: proposal
        )
        navigationBarNode?.place(
            in: .zero,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: frame.width, height: Constants.navigationBarHeight)
        )
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        guard self.environment.version != prevVersion else { return }
        viewInputs.environment = self.environment
        let childInputs = makeContentInputs(
            reservingNavigationBarHeight: navigationBarNode != nil && Self.nodeConsumesTopSafeArea(currentContentNode)
                ? Constants.navigationBarHeight
                : 0
        )
        currentContentNode.updateEnvironment(childInputs.environment)
        syncNavigationBar()
    }

    private static func nodeConsumesTopSafeArea(_ node: ViewNode) -> Bool {
        if node is ScrollViewNode {
            return true
        }

        if let modifier = node as? ViewModifierNode {
            return nodeConsumesTopSafeArea(modifier.contentNode)
        }

        if let container = node as? ViewContainerNode {
            return container.nodes.contains { child in
                nodeConsumesTopSafeArea(child)
            }
        }

        return false
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        currentContentNode.updateViewOwner(owner)
        navigationBarNode?.updateViewOwner(owner)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }
        if let navigationBarNode {
            let barPoint = navigationBarNode.convert(point, from: self)
            if let hit = navigationBarNode.hitTest(barPoint, with: event) {
                return hit
            }
        }
        let newPoint = currentContentNode.convert(point, from: self)
        return currentContentNode.hitTest(newPoint, with: event)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)
        currentContentNode.draw(with: context)
        navigationBarNode?.draw(with: context)
    }

    override func update(_ deltaTime: TimeInterval) {
        currentContentNode.update(deltaTime)
        navigationBarNode?.update(deltaTime)
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        navigationBarNode?.findNodeById(id) ?? currentContentNode.findNodeById(id)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        super.findNodyByAccessibilityIdentifier(identifier)
            ?? navigationBarNode?.findNodyByAccessibilityIdentifier(identifier)
            ?? currentContentNode.findNodyByAccessibilityIdentifier(identifier)
    }

    override func invalidateContent() {
        rebuildContent()
    }

    override func didMove(to parent: ViewNode?) {
        super.didMove(to: parent)
        if parent == nil {
            currentContentNode.parent = nil
            navigationBarNode?.parent = nil
        }
    }

    override func onMouseEvent(_ event: MouseEvent) {
        currentContentNode.onMouseEvent(event)
        navigationBarNode?.onMouseEvent(event)
    }

    override func onReceiveEvent(_ event: any InputEvent) {
        currentContentNode.onReceiveEvent(event)
        navigationBarNode?.onReceiveEvent(event)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        currentContentNode.onTouchesEvent(touches)
        navigationBarNode?.onTouchesEvent(touches)
    }
}

// MARK: - NavigationBarNode

private final class NavigationBarNode: ViewNode {
    private enum Constants {
        static let height: Float = 92
        static let horizontalPadding: Float = 16
        static let itemSpacing: Float = 10
        static let controlHeight: Float = 44
        static let titleHorizontalInset: Float = 72
        static let leadingTitleOffset: Float = 54
        static let minimumCenteredTitleWidth: Float = 120
        static let titleBaselineY: Float = 24
    }

    private var configuration: NavigationBarConfiguration
    private var leadingItems: NavigationBarItemContent?
    private var trailingItems: NavigationBarItemContent?
    private var showsBackButton: Bool
    private weak var navigationContext: NavigationContext?
    private var inputs: _ViewInputs

    private var titleNode: ViewNode?
    private var backButtonNode: ViewNode?
    private var leadingItemsNode: ViewNode?
    private var trailingItemsNode: ViewNode?

    init(
        configuration: NavigationBarConfiguration,
        leadingItems: NavigationBarItemContent?,
        trailingItems: NavigationBarItemContent?,
        showsBackButton: Bool,
        navigationContext: NavigationContext,
        inputs: _ViewInputs
    ) {
        self.configuration = configuration
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.showsBackButton = showsBackButton
        self.navigationContext = navigationContext
        self.inputs = inputs
        super.init(content: AnyView(EmptyView()))
        rebuildChildren()
        updateEnvironment(inputs.environment)
    }

    func update(
        configuration: NavigationBarConfiguration,
        leadingItems: NavigationBarItemContent?,
        trailingItems: NavigationBarItemContent?,
        showsBackButton: Bool,
        inputs: _ViewInputs
    ) {
        self.configuration = configuration
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.showsBackButton = showsBackButton
        self.inputs = inputs
        rebuildChildren()
        updateEnvironment(inputs.environment)
        performLayout()
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        Size(width: proposal.width ?? 0, height: Constants.height)
    }

    override func performLayout() {
        let titlePosition = resolvedTitlePosition()
        let centerY = Constants.titleBaselineY
        var leadingX = Constants.horizontalPadding
        let reservedTitleWidth = titlePosition == .center || titlePosition == .automatic
            ? Constants.minimumCenteredTitleWidth
            : 0
        let maxItemWidth = max(
            0,
            (frame.width - Constants.horizontalPadding * 2 - reservedTitleWidth - Constants.itemSpacing * 2) * 0.5
        )

        if let backButtonNode {
            backButtonNode.place(
                in: Point(x: leadingX, y: centerY),
                anchor: .leading,
                proposal: ProposedViewSize(width: Constants.controlHeight, height: Constants.controlHeight)
            )
            leadingX += Constants.controlHeight + Constants.itemSpacing
        }

        if let leadingItemsNode {
            let measured = leadingItemsNode.sizeThatFits(.unspecified)
            let width = min(measured.width, maxItemWidth)
            leadingItemsNode.place(
                in: Point(x: leadingX, y: centerY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: Constants.controlHeight)
            )
            leadingX += width + Constants.itemSpacing
        }

        var trailingWidth: Float = 0
        if let trailingItemsNode {
            let measured = trailingItemsNode.sizeThatFits(.unspecified)
            trailingWidth = min(measured.width, maxItemWidth)
            trailingItemsNode.place(
                in: Point(x: frame.width - Constants.horizontalPadding, y: centerY),
                anchor: .trailing,
                proposal: ProposedViewSize(width: trailingWidth, height: Constants.controlHeight)
            )
        }

        if let titleNode {
            switch titlePosition {
            case .leading:
                let availableWidth = max(0, frame.width - leadingX - Constants.horizontalPadding)
                titleNode.place(
                    in: Point(x: leadingX, y: centerY),
                    anchor: .leading,
                    proposal: ProposedViewSize(width: availableWidth, height: Constants.controlHeight)
                )
            case .automatic, .center:
                let occupiedSideWidth = max(
                    leadingX,
                    Constants.horizontalPadding + trailingWidth + Constants.itemSpacing
                )
                titleNode.place(
                    in: Point(x: frame.width * 0.5, y: centerY),
                    anchor: .center,
                    proposal: ProposedViewSize(
                        width: max(0, frame.width - occupiedSideWidth * 2),
                        height: Constants.controlHeight
                    )
                )
            }
        }
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        guard self.environment.version != prevVersion else { return }
        inputs.environment = self.environment
        updateChildEnvironments()
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        for node in childNodes {
            node.updateViewOwner(owner)
        }
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }
        for node in childNodes.reversed() {
            let childPoint = node.convert(point, from: self)
            if let hit = node.hitTest(childPoint, with: event) {
                return hit
            }
        }
        return nil
    }

    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        super.point(inside: point, with: event) || childNodes.contains { node in
            let childPoint = node.convert(point, from: self)
            return node.point(inside: childPoint, with: event)
        }
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)
        context.drawLinearGradient(
            ResolvedLinearGradient(
                startPoint: .top,
                endPoint: .bottom,
                stops: [
                    Gradient.Stop(color: .black.opacity(0.98), location: 0),
                    Gradient.Stop(color: .black.opacity(0.72), location: 0.48),
                    Gradient.Stop(color: .black.opacity(0), location: 1),
                ]
            ),
            in: Rect(origin: .zero, size: frame.size)
        )
        for node in childNodes {
            node.draw(with: context)
        }
    }

    override func update(_ deltaTime: TimeInterval) {
        for node in childNodes {
            node.update(deltaTime)
        }
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        childNodes.lazy.compactMap { $0.findNodeById(id) }.first
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        super.findNodyByAccessibilityIdentifier(identifier)
            ?? childNodes.lazy.compactMap { $0.findNodyByAccessibilityIdentifier(identifier) }.first
    }

    override func didMove(to parent: ViewNode?) {
        super.didMove(to: parent)
        if parent == nil {
            for node in childNodes {
                node.parent = nil
            }
        }
    }

    private var childNodes: [ViewNode] {
        [
            titleNode,
            backButtonNode,
            leadingItemsNode,
            trailingItemsNode,
        ].compactMap { $0 }
    }

    private func rebuildChildren() {
        for node in childNodes {
            node.parent = nil
        }

        titleNode = makeTitleNode()
        backButtonNode = showsBackButton ? makeBackButtonNode() : nil
        leadingItemsNode = leadingItems?.makeNode(navigationBarItemInputs())
        trailingItemsNode = trailingItems?.makeNode(navigationBarItemInputs())

        for node in childNodes {
            node.parent = self
            if let owner {
                node.updateViewOwner(owner)
            }
        }
        updateChildEnvironments()
    }

    private func makeTitleNode() -> ViewNode? {
        guard let title = configuration.title, !title.isEmpty else { return nil }
        let pointSize: Double = resolvedTitlePosition() == .leading ? 22 : 16
        let view = Text(title)
            .font(.system(size: pointSize))
            .foregroundColor(.white)
            .lineLimit(1)
        return Text._makeView(_ViewGraphNode(value: view), inputs: inputs).node
    }

    private func makeBackButtonNode() -> ViewNode {
        let view = Button(action: { [weak navigationContext] in
            navigationContext?.pop()
        }) {
            Text("<")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: Constants.controlHeight, height: Constants.controlHeight)
        }
        return Button._makeView(_ViewGraphNode(value: view), inputs: navigationBarItemInputs()).node
    }

    private func navigationBarItemInputs() -> _ViewInputs {
        var styledInputs = inputs
        styledInputs.environment.buttonStyle = NavigationBarButtonStyle()
        return styledInputs
    }

    private func updateChildEnvironments() {
        titleNode?.updateEnvironment(inputs.environment)

        let itemEnvironment = navigationBarItemInputs().environment
        backButtonNode?.updateEnvironment(itemEnvironment)
        leadingItemsNode?.updateEnvironment(itemEnvironment)
        trailingItemsNode?.updateEnvironment(itemEnvironment)
    }

    private func resolvedTitlePosition() -> NavigationTitlePosition {
        switch configuration.titlePosition {
        case .leading, .center:
            return configuration.titlePosition
        case .automatic:
            switch configuration.titleDisplayMode {
            case .large:
                return .leading
            case .automatic, .inline:
                return .center
            }
        }
    }
}
