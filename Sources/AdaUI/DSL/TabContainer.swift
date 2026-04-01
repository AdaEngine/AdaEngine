//
//  TabContainer.swift
//  AdaEngine
//
//  Created by Codex on 24.03.2026.
//

import AdaInput
import AdaRender
import AdaText
import AdaUtils
import Math

// MARK: - TabViewPosition

/// The position of the tab bar relative to the content.
public enum TabViewPosition: Sendable {
    case top
    case bottom
    case left
    case right
}

// MARK: - TabLabelStyle

/// Controls which parts of a tab label are displayed.
public enum TabLabelStyle: Sendable {
    /// Show only the image.
    case compact
    /// Show both image and text.
    case regular
}

// MARK: - TabBarElement

enum TabBarElement {
    case tab(
        label: String?,
        image: Image?,
        value: AnyHashable,
        makeContent: @MainActor (_ViewInputs) -> ViewNode
    )
    case sectionHeader(String)
    case spacer
    case divider
}

// MARK: - _TabItem

@MainActor
protocol _TabItem {
    func _extractTabBarElements(inputs: _ViewInputs) -> [TabBarElement]
}

// MARK: - Tab

/// A single tab item with a label, optional image, and associated content.
@MainActor @preconcurrency
public struct Tab<Value: Hashable, Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let label: String?
    let image: Image?
    let value: Value
    let content: () -> Content

    /// Creates a tab with a text label, optional image, and content.
    public init(
        _ label: String,
        image: Image? = nil,
        value: Value,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.image = image
        self.value = value
        self.content = content
    }

    /// Creates a tab with only an image and content.
    public init(
        image: Image,
        value: Value,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = nil
        self.image = image
        self.value = value
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        Content._makeView(_ViewGraphNode(value: content()), inputs: context).node
    }
}

extension Tab: _TabItem {
    func _extractTabBarElements(inputs: _ViewInputs) -> [TabBarElement] {
        let label = self.label
        let image = self.image
        let hashableValue = AnyHashable(value)
        let contentClosure = content
        let makeContent: @MainActor (_ViewInputs) -> ViewNode = { inputs in
            Content._makeView(_ViewGraphNode(value: contentClosure()), inputs: inputs).node
        }
        return [.tab(label: label, image: image, value: hashableValue, makeContent: makeContent)]
    }
}

// MARK: - TabSection

/// A labeled group of tabs in a TabView.
@MainActor @preconcurrency
public struct TabSection<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let title: String
    let content: () -> Content

    public init(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        Content._makeView(_ViewGraphNode(value: content()), inputs: context).node
    }
}

extension TabSection: _TabItem {
    func _extractTabBarElements(inputs: _ViewInputs) -> [TabBarElement] {
        var elements: [TabBarElement] = [.sectionHeader(title)]
        elements += extractTabBarElements(from: content(), inputs: inputs)
        return elements
    }
}

// MARK: - Spacer + Divider as tab bar items

extension Spacer: _TabItem {
    @MainActor func _extractTabBarElements(inputs: _ViewInputs) -> [TabBarElement] {
        [.spacer]
    }
}

extension Divider: _TabItem {
    @MainActor func _extractTabBarElements(inputs: _ViewInputs) -> [TabBarElement] {
        [.divider]
    }
}

// MARK: - TabView

/// A view that switches between multiple child views using a tab bar.
@MainActor @preconcurrency
public struct TabView<Selection: Hashable, Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let selection: Binding<Selection>
    let content: () -> Content

    public init(
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.selection = selection
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let contentView = content()
        let elements = extractTabBarElements(from: contentView, inputs: context)
        return TabViewNode(inputs: context, tabView: self, elements: elements)
    }
}

// MARK: - EnvironmentValues

extension EnvironmentValues {
    var tabViewPosition: TabViewPosition {
        get { self[TabViewPositionKey.self] }
        set { self[TabViewPositionKey.self] = newValue }
    }

    var tabLabelStyle: TabLabelStyle {
        get { self[TabLabelStyleKey.self] }
        set { self[TabLabelStyleKey.self] = newValue }
    }

    private struct TabViewPositionKey: EnvironmentKey {
        static let defaultValue: TabViewPosition = .top
    }

    private struct TabLabelStyleKey: EnvironmentKey {
        static let defaultValue: TabLabelStyle = .regular
    }
}

public extension View {
    /// Sets the position of the tab bar in a TabView.
    func tabViewPosition(_ position: TabViewPosition) -> some View {
        self.environment(\.tabViewPosition, position)
    }

    /// Sets the label style for tabs in a TabView.
    func tabLabelStyle(_ style: TabLabelStyle) -> some View {
        self.environment(\.tabLabelStyle, style)
    }
}

// MARK: - Tab bar element extraction

@MainActor
private func extractTabBarElements<V: View>(from view: V, inputs: _ViewInputs) -> [TabBarElement] {
    if let item = view as? any _TabItem {
        return item._extractTabBarElements(inputs: inputs)
    }

    let mirror = Mirror(reflecting: view)
    var result: [TabBarElement] = []

    for (_, child) in mirror.children {
        if let childView = child as? any View {
            result += extractTabBarElements(from: childView, inputs: inputs)
        } else {
            let childMirror = Mirror(reflecting: child)
            for (_, grandchild) in childMirror.children {
                if let grandchildView = grandchild as? any View {
                    result += extractTabBarElements(from: grandchildView, inputs: inputs)
                }
            }
        }
    }

    return result
}

// MARK: - Constants

private enum TabViewConstants {
    static var tabBarHeight: Float { 48 }
    static var tabBarWidth: Float { 200 }
    static var tabBarBorderWidth: Float { 1 }
    static var tabHorizontalPadding: Float { 16 }
    static var iconSize: Float { 18 }
    static var iconTextGap: Float { 4 }
    static var selectedIndicatorThickness: Float { 3 }
    static var sectionHeaderFontSize: Float { 11 }
    static var sectionHeaderHeight: Float { 28 }

    static var tabTextColor: Color { .fromHex(0x666666) }
    static var selectedTabTextColor: Color { .fromHex(0xF0F0F0) }
    static var indicatorColor: Color { .fromHex(0xFF2D6F) }
    static var borderColor: Color { .fromHex(0x2A2A2A) }
    static var sectionHeaderColor: Color { .fromHex(0x555555) }
    static var highlightColor: Color { .fromHex(0x1A1A1A) }
    static var tapMovementThreshold: Float { 10 }
}

// MARK: - TabViewNode

final class TabViewNode<Selection: Hashable, Content: View>: ViewNode {

    private var elements: [TabBarElement]
    private var selectionBinding: Binding<Selection>
    private var position: TabViewPosition
    private var viewInputs: _ViewInputs

    private var tabBarNode: LayoutViewContainerNode
    private var contentNode: ViewNode
    private var cachedContentNodes: [AnyHashable: ViewNode] = [:]

    private var tabBarHeight: Float { TabViewConstants.tabBarHeight }
    private var tabBarWidth: Float { TabViewConstants.tabBarWidth }
    private var isHorizontalBar: Bool { position == .top || position == .bottom }

    init(inputs: _ViewInputs, tabView: TabView<Selection, Content>, elements: [TabBarElement]) {
        self.elements = elements
        self.selectionBinding = tabView.selection
        self.position = inputs.environment.tabViewPosition
        self.viewInputs = inputs

        let selected = AnyHashable(tabView.selection.wrappedValue)

        self.tabBarNode = Self.buildTabBar(
            elements: elements,
            selected: selected,
            position: inputs.environment.tabViewPosition,
            inputs: inputs,
            onSelect: { _ in }
        )
        self.contentNode = Self.buildContent(
            for: selected,
            from: elements,
            inputs: inputs
        )

        super.init(content: tabView)

        self.cachedContentNodes[selected] = self.contentNode
        self.tabBarNode.parent = self
        self.contentNode.parent = self

        let weakSelf = WeakBox(self)
        self.tabBarNode = Self.buildTabBar(
            elements: elements,
            selected: selected,
            position: inputs.environment.tabViewPosition,
            inputs: inputs,
            onSelect: { value in
                weakSelf.value?.selectTab(value)
            }
        )
        self.tabBarNode.parent = self
    }

    override var canBecomeFocused: Bool { false }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let width = proposal.width ?? 300
        let height = proposal.height ?? 300

        if isHorizontalBar {
            let contentHeight = proposal.height.map { max(0, $0 - tabBarHeight) }
            return Size(
                width: width,
                height: tabBarHeight + (contentHeight ?? height)
            )
        } else {
            let contentWidth = proposal.width.map { max(0, $0 - tabBarWidth) }
            return Size(
                width: tabBarWidth + (contentWidth ?? width),
                height: height
            )
        }
    }

    override func performLayout() {
        switch position {
        case .top:
            tabBarNode.place(
                in: Point(x: frame.width * 0.5, y: tabBarHeight * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: frame.width, height: tabBarHeight)
            )
            let contentHeight = max(0, frame.height - tabBarHeight)
            contentNode.place(
                in: Point(x: frame.width * 0.5, y: tabBarHeight + contentHeight * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: frame.width, height: contentHeight)
            )

        case .bottom:
            let contentHeight = max(0, frame.height - tabBarHeight)
            contentNode.place(
                in: Point(x: frame.width * 0.5, y: contentHeight * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: frame.width, height: contentHeight)
            )
            tabBarNode.place(
                in: Point(x: frame.width * 0.5, y: contentHeight + tabBarHeight * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: frame.width, height: tabBarHeight)
            )

        case .left:
            tabBarNode.place(
                in: Point(x: tabBarWidth * 0.5, y: frame.height * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: tabBarWidth, height: frame.height)
            )
            let contentWidth = max(0, frame.width - tabBarWidth)
            contentNode.place(
                in: Point(x: tabBarWidth + contentWidth * 0.5, y: frame.height * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: contentWidth, height: frame.height)
            )

        case .right:
            let contentWidth = max(0, frame.width - tabBarWidth)
            contentNode.place(
                in: Point(x: contentWidth * 0.5, y: frame.height * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: contentWidth, height: frame.height)
            )
            tabBarNode.place(
                in: Point(x: contentWidth + tabBarWidth * 0.5, y: frame.height * 0.5),
                anchor: .center,
                proposal: ProposedViewSize(width: tabBarWidth, height: frame.height)
            )
        }
    }

    override func update(from newNode: ViewNode) {
        guard let other = newNode as? TabViewNode<Selection, Content> else { return }
        let oldValues = Self.tabValues(from: elements)
        let newValues = Self.tabValues(from: other.elements)
        let elementsChanged = oldValues != newValues
        let positionChanged = self.position != other.position

        for key in oldValues.subtracting(newValues) {
            cachedContentNodes[key]?.parent = nil
            cachedContentNodes.removeValue(forKey: key)
        }
        self.elements = other.elements
        self.selectionBinding = other.selectionBinding
        self.position = other.position
        self.viewInputs = other.viewInputs
        super.update(from: other)

        if elementsChanged || positionChanged {
            rebuildAll()
        } else {
            updateSelectionOnly()
        }
    }

    override func invalidateContent() {
        rebuildAll()
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        guard self.environment.version != prevVersion else { return }

        tabBarNode.updateEnvironment(self.environment)

        // Zero the safe area edge the tab bar occupies so content children
        // don't add redundant inset for an edge the tab bar already covers.
        var contentEnv = self.environment
        switch position {
        case .top:    contentEnv.safeAreaInsets.top = 0
        case .bottom: contentEnv.safeAreaInsets.bottom = 0
        case .left:   contentEnv.safeAreaInsets.leading = 0
        case .right:  contentEnv.safeAreaInsets.trailing = 0
        }
        for cachedNode in cachedContentNodes.values {
            cachedNode.updateEnvironment(contentEnv)
        }
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        tabBarNode.updateViewOwner(owner)
        for cachedNode in cachedContentNodes.values {
            cachedNode.updateViewOwner(owner)
        }
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }

        let tabBarPoint = tabBarNode.convert(point, from: self)
        if let hit = tabBarNode.hitTest(tabBarPoint, with: event) {
            return hit
        }

        let contentPoint = contentNode.convert(point, from: self)
        return contentNode.hitTest(contentPoint, with: event)
    }

    override func draw(with context: UIGraphicsContext) {
        var ctx = context
        ctx.environment = environment
        ctx.translateBy(x: frame.origin.x, y: -frame.origin.y)

        tabBarNode.draw(with: ctx)
        drawSeparator(with: ctx)
        contentNode.draw(with: ctx)
    }

    override func update(_ deltaTime: TimeInterval) {
        tabBarNode.update(deltaTime)
        contentNode.update(deltaTime)
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        tabBarNode.findNodeById(id) ?? contentNode.findNodeById(id)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        if let result = super.findNodyByAccessibilityIdentifier(identifier) { return result }
        return tabBarNode.findNodyByAccessibilityIdentifier(identifier)
            ?? contentNode.findNodyByAccessibilityIdentifier(identifier)
    }

    // MARK: - Private

    private func drawSeparator(with context: UIGraphicsContext) {
        switch position {
        case .top:
            context.drawLine(
                start: Point(0, -tabBarHeight),
                end: Point(frame.width, -tabBarHeight),
                lineWidth: TabViewConstants.tabBarBorderWidth,
                color: TabViewConstants.borderColor
            )
        case .bottom:
            let contentHeight = max(0, frame.height - tabBarHeight)
            context.drawLine(
                start: Point(0, -contentHeight),
                end: Point(frame.width, -contentHeight),
                lineWidth: TabViewConstants.tabBarBorderWidth,
                color: TabViewConstants.borderColor
            )
        case .left:
            context.drawLine(
                start: Point(tabBarWidth, 0),
                end: Point(tabBarWidth, -frame.height),
                lineWidth: TabViewConstants.tabBarBorderWidth,
                color: TabViewConstants.borderColor
            )
        case .right:
            let contentWidth = max(0, frame.width - tabBarWidth)
            context.drawLine(
                start: Point(contentWidth, 0),
                end: Point(contentWidth, -frame.height),
                lineWidth: TabViewConstants.tabBarBorderWidth,
                color: TabViewConstants.borderColor
            )
        }
    }

    private func selectTab(_ value: AnyHashable) {
        guard let typedValue = value.base as? Selection,
              selectionBinding.wrappedValue != typedValue else { return }
        // Setting wrappedValue triggers StateStorage.update() → invalidateContent() on
        // the parent State owner → body re-evaluation → TabViewNode.update(from:) →
        // updateSelectionOnly(). The explicit rebuildAll() that used to follow was redundant.
        selectionBinding.wrappedValue = typedValue
    }

    /// Fast path: only selection changed, no structural change to elements.
    /// Updates tab bar button states and swaps the content node without rebuilding nodes.
    private func updateSelectionOnly() {
        let selected = AnyHashable(selectionBinding.wrappedValue)

        // Update selection state on existing tab bar buttons in-place (no rebuild)
        for node in tabBarNode.nodes {
            guard let button = node as? TabItemButtonNode else { continue }
            button.updateSelection(selected)
        }

        // Swap content node only if selection actually changed
        let wasAlreadyCached = cachedContentNodes[selected] != nil
        let newContentNode = getOrCreateContentNode(for: selected)
        if contentNode !== newContentNode {
            contentNode = newContentNode
            contentNode.parent = self
        }

        // Only propagate environment and owner to newly created content nodes.
        // Cached nodes already have the correct environment and owner from when they were first shown.
        // Phase 2's version guard in updateEnvironment also protects against redundant cascades.
        if !wasAlreadyCached, let owner {
            var contentEnv = environment
            switch position {
            case .top:    contentEnv.safeAreaInsets.top = 0
            case .bottom: contentEnv.safeAreaInsets.bottom = 0
            case .left:   contentEnv.safeAreaInsets.leading = 0
            case .right:  contentEnv.safeAreaInsets.trailing = 0
            }
            newContentNode.updateViewOwner(owner)
            newContentNode.updateEnvironment(contentEnv)
        }

        self.invalidateNearestLayer()
        if let containerView = self.owner?.containerView {
            containerView.setNeedsDisplay(in: self.absoluteFrame())
        }
        self.performLayout()
    }

    private func rebuildAll() {
        let selected = AnyHashable(selectionBinding.wrappedValue)
        let weakSelf = WeakBox(self)

        tabBarNode.parent = nil
        tabBarNode = Self.buildTabBar(
            elements: elements,
            selected: selected,
            position: position,
            inputs: viewInputs,
            onSelect: { value in weakSelf.value?.selectTab(value) }
        )
        tabBarNode.parent = self
        if let owner { tabBarNode.updateViewOwner(owner) }
        tabBarNode.updateEnvironment(environment)

        let newContentNode = getOrCreateContentNode(for: selected)
        if contentNode !== newContentNode {
            contentNode = newContentNode
            contentNode.parent = self
        }
        var contentEnv = environment
        switch position {
        case .top:    contentEnv.safeAreaInsets.top = 0
        case .bottom: contentEnv.safeAreaInsets.bottom = 0
        case .left:   contentEnv.safeAreaInsets.leading = 0
        case .right:  contentEnv.safeAreaInsets.trailing = 0
        }
        if let owner {
            for cachedNode in cachedContentNodes.values {
                cachedNode.updateViewOwner(owner)
            }
        }
        contentNode.updateEnvironment(contentEnv)

        self.invalidateNearestLayer()
        if let containerView = self.owner?.containerView {
            containerView.setNeedsDisplay(in: self.absoluteFrame())
        }
        self.performLayout()
    }

    private func getOrCreateContentNode(for value: AnyHashable) -> ViewNode {
        if let cached = cachedContentNodes[value] {
            return cached
        }
        for element in elements {
            if case .tab(_, _, let v, let makeContent) = element, v == value {
                let node = makeContent(viewInputs)
                node.parent = self
                cachedContentNodes[value] = node
                return node
            }
        }
        return EmptyView._makeView(_ViewGraphNode(value: EmptyView()), inputs: viewInputs).node
    }

    private static func tabValues(from elements: [TabBarElement]) -> Set<AnyHashable> {
        Set(elements.compactMap { elem -> AnyHashable? in
            if case .tab(_, _, let v, _) = elem { return v }
            return nil
        })
    }

    private static func buildTabBar(
        elements: [TabBarElement],
        selected: AnyHashable,
        position: TabViewPosition,
        inputs: _ViewInputs,
        onSelect: @escaping (AnyHashable) -> Void
    ) -> LayoutViewContainerNode {
        let isHorizontal = position == .top || position == .bottom
        let nodes = buildTabBarNodes(
            elements: elements,
            selected: selected,
            isHorizontal: isHorizontal,
            inputs: inputs,
            onSelect: onSelect
        )
        let layout: any Layout = isHorizontal
            ? EqualWidthTabBarLayout()
            : VStackLayout(alignment: .leading, spacing: 0)
        return LayoutViewContainerNode(layout: layout, content: EmptyView(), nodes: nodes)
    }

    private static func buildTabBarNodes(
        elements: [TabBarElement],
        selected: AnyHashable,
        isHorizontal: Bool,
        inputs: _ViewInputs,
        onSelect: @escaping (AnyHashable) -> Void
    ) -> [ViewNode] {
        var nodes: [ViewNode] = []
        for element in elements {
            switch element {
            case .tab(let label, let image, let value, _):
                let button = TabItemButton(
                    label: label,
                    image: image,
                    value: value,
                    isSelected: value == selected,
                    isHorizontalBar: isHorizontal,
                    action: { onSelect(value) }
                )
                let node = TabItemButtonNode(content: button, inputs: inputs)
                nodes.append(node)
            case .sectionHeader(let title):
                guard !isHorizontal else { continue }
                let header = TabSectionHeader(title: title)
                let node = TabSectionHeaderNode(content: header, inputs: inputs)
                nodes.append(node)
            case .spacer:
                nodes.append(SpacerViewNode(minLength: nil, content: Spacer()))
            case .divider:
                nodes.append(DividerNode(content: Divider()))
            }
        }
        return nodes
    }

    private static func buildContent(
        for selected: AnyHashable,
        from elements: [TabBarElement],
        inputs: _ViewInputs
    ) -> ViewNode {
        for element in elements {
            if case .tab(_, _, let value, let makeContent) = element, value == selected {
                return makeContent(inputs)
            }
        }
        return EmptyView._makeView(_ViewGraphNode(value: EmptyView()), inputs: inputs).node
    }
}

// MARK: - Equal Width Tab Bar Layout

private struct EqualWidthTabBarLayout: Layout {
    typealias AnimatableData = EmptyAnimatableData
    static var layoutProperties = LayoutProperties(stackOrientation: .horizontal)

    func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> Size {
        let width = proposal.width ?? (Float(subviews.count) * TabViewConstants.tabBarHeight)
        let height = proposal.height ?? TabViewConstants.tabBarHeight
        return Size(width: width, height: height)
    }

    func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard !subviews.isEmpty else { return }
        let itemWidth = bounds.width / Float(subviews.count)
        var x = bounds.minX
        for subview in subviews {
            let childProposal = ProposedViewSize(width: itemWidth, height: bounds.height)
            subview.place(at: Point(x: x, y: bounds.midY), anchor: .leading, proposal: childProposal)
            x += itemWidth
        }
    }
}

// MARK: - Tab Item Button

private struct TabItemButton: View, ViewNodeBuilder {
    typealias Body = Never
    var body: Never { fatalError() }

    let label: String?
    let image: Image?
    let value: AnyHashable
    let isSelected: Bool
    let isHorizontalBar: Bool
    let action: () -> Void

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TabItemButtonNode(content: self, inputs: context)
    }
}

private final class TabItemButtonNode: ViewNode {

    private var label: String?
    private var image: Image?
    private var isSelected: Bool
    private var isHorizontalBar: Bool
    private var action: () -> Void
    private var isHighlighted: Bool = false
    private var iconTexture: Texture2D?
    private var touchStartLocation: Point?
    private(set) var value: AnyHashable

    init(content: TabItemButton, inputs: _ViewInputs) {
        self.label = content.label
        self.image = content.image
        self.isSelected = content.isSelected
        self.isHorizontalBar = content.isHorizontalBar
        self.action = content.action
        self.value = content.value
        self.iconTexture = content.image.map { Texture2D(image: $0) }
        super.init(content: content)
        self.updateEnvironment(inputs.environment)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if isHorizontalBar {
            let width = proposal.width ?? TabViewConstants.tabBarHeight
            let height = proposal.height ?? TabViewConstants.tabBarHeight
            return Size(width: width, height: height)
        } else {
            let width = proposal.width ?? TabViewConstants.tabBarWidth
            return Size(width: width, height: TabViewConstants.tabBarHeight)
        }
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }
        return self
    }

    override func onMouseEvent(_ event: MouseEvent) {
        switch event.phase {
        case .began:
            isHighlighted = true
        case .changed:
            break
        case .ended:
            let was = isHighlighted
            isHighlighted = false
            if was { action() }
        case .cancelled:
            isHighlighted = false
        }
        requestDisplay()
    }

    override func onMouseLeave() {
        isHighlighted = false
        requestDisplay()
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        guard let touch = touches.first else { return }

        switch touch.phase {
        case .began:
            touchStartLocation = touch.location
            isHighlighted = true
        case .moved:
            if let start = touchStartLocation {
                let dx = touch.location.x - start.x
                let dy = touch.location.y - start.y
                let threshold = TabViewConstants.tapMovementThreshold
                if dx * dx + dy * dy > threshold * threshold {
                    isHighlighted = false
                }
            }
        case .ended:
            let was = isHighlighted
            isHighlighted = false
            touchStartLocation = nil
            if was { action() }
        case .cancelled:
            isHighlighted = false
            touchStartLocation = nil
        }

        requestDisplay()
    }

    override func draw(with context: UIGraphicsContext) {
        var ctx = context
        ctx.environment = environment
        ctx.translateBy(x: frame.origin.x, y: -frame.origin.y)

        let bounds = Rect(x: 0, y: 0, width: frame.width, height: frame.height)

        if isHighlighted {
            ctx.drawRect(bounds, color: TabViewConstants.highlightColor)
        }

        drawContent(in: bounds, with: ctx)
        drawIndicator(in: bounds, with: ctx)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? TabItemButtonNode else { return }
        self.label = other.label
        self.image = other.image
        self.isSelected = other.isSelected
        self.isHorizontalBar = other.isHorizontalBar
        self.action = other.action
        self.value = other.value
        if let img = other.image, self.iconTexture == nil {
            self.iconTexture = Texture2D(image: img)
        }
    }

    func updateSelection(_ selected: AnyHashable) {
        let shouldBeSelected = AnyHashable(value) == selected
        guard isSelected != shouldBeSelected else { return }
        isSelected = shouldBeSelected
        requestDisplay()
    }

    // MARK: - Drawing helpers

    private func drawContent(in bounds: Rect, with context: UIGraphicsContext) {
        let isCompact = environment.tabLabelStyle == .compact
        let hasIcon = iconTexture != nil
        let hasLabel = !isCompact && label != nil && !label!.isEmpty

        switch (hasIcon, hasLabel) {
        case (true, false):
            drawIcon(centeredIn: bounds, with: context)
        case (false, true):
            drawLabel(centeredIn: bounds, with: context)
        case (true, true):
            if isHorizontalBar {
                drawIconAboveLabel(in: bounds, with: context)
            } else {
                drawIconBesideLabel(in: bounds, with: context)
            }
        default:
            break
        }
    }

    private func drawIcon(centeredIn bounds: Rect, with context: UIGraphicsContext) {
        guard let texture = iconTexture else { return }
        let size = TabViewConstants.iconSize
        let iconRect = Rect(
            x: (bounds.width - size) * 0.5,
            y: (bounds.height - size) * 0.5,
            width: size,
            height: size
        )
        let tint: Color = isSelected ? TabViewConstants.selectedTabTextColor : TabViewConstants.tabTextColor
        context.drawRect(iconRect, texture: texture, color: tint)
    }

    private func drawLabel(centeredIn bounds: Rect, with context: UIGraphicsContext) {
        guard let text = label, let font = resolvedFont() else { return }
        let pointSize = resolvedPointSize()
        let textColor: Color = isSelected ? TabViewConstants.selectedTabTextColor : TabViewConstants.tabTextColor
        renderText(text, font: font, color: textColor, centerX: bounds.width * 0.5, centerY: bounds.height * 0.5, pointSize: pointSize, in: context)
    }

    private func drawIconAboveLabel(in bounds: Rect, with context: UIGraphicsContext) {
        guard let texture = iconTexture, let text = label, let font = resolvedFont() else { return }
        let pointSize = resolvedPointSize()
        let tint: Color = isSelected ? TabViewConstants.selectedTabTextColor : TabViewConstants.tabTextColor
        let iconSize = TabViewConstants.iconSize
        let gap = TabViewConstants.iconTextGap
        let totalH = iconSize + gap + pointSize
        let startY = (bounds.height - totalH) * 0.5

        let iconRect = Rect(x: (bounds.width - iconSize) * 0.5, y: startY, width: iconSize, height: iconSize)
        context.drawRect(iconRect, texture: texture, color: tint)
        renderText(text, font: font, color: tint, centerX: bounds.width * 0.5, centerY: startY + iconSize + gap + pointSize * 0.5, pointSize: pointSize, in: context)
    }

    private func drawIconBesideLabel(in bounds: Rect, with context: UIGraphicsContext) {
        guard let texture = iconTexture, let text = label, let font = resolvedFont() else { return }
        let pointSize = resolvedPointSize()
        let tint: Color = isSelected ? TabViewConstants.selectedTabTextColor : TabViewConstants.tabTextColor
        let iconSize = TabViewConstants.iconSize
        let gap = TabViewConstants.iconTextGap
        let startX = TabViewConstants.tabHorizontalPadding

        let iconRect = Rect(x: startX, y: (bounds.height - iconSize) * 0.5, width: iconSize, height: iconSize)
        context.drawRect(iconRect, texture: texture, color: tint)
        renderText(text, font: font, color: tint, centerX: startX + iconSize + gap + estimatedTextWidth(text, pointSize: pointSize) * 0.5, centerY: bounds.height * 0.5, pointSize: pointSize, in: context)
    }

    private func drawIndicator(in bounds: Rect, with context: UIGraphicsContext) {
        guard isSelected else { return }
        let t = TabViewConstants.selectedIndicatorThickness
        switch isHorizontalBar {
        case true:
            // Indicator at bottom of button
            context.drawRect(
                Rect(x: 0, y: bounds.height - t, width: bounds.width, height: t),
                color: TabViewConstants.indicatorColor
            )
        case false:
            // Indicator on left edge of button
            context.drawRect(
                Rect(x: 0, y: 0, width: t, height: bounds.height),
                color: TabViewConstants.indicatorColor
            )
        }
    }

    private func renderText(
        _ text: String,
        font: Font,
        color: Color,
        centerX: Float,
        centerY: Float,
        pointSize: Float,
        in context: UIGraphicsContext
    ) {
        var attributes = TextAttributeContainer()
        attributes.font = font
        attributes.foregroundColor = color
        let attributedText = AttributedText(text, attributes: attributes)
        let container = TextContainer(text: attributedText, textAlignment: .center)
        let layoutManager = TextLayoutManager()
        layoutManager.setTextContainer(container)
        let textW = estimatedTextWidth(text, pointSize: pointSize)
        layoutManager.fitToSize(Size(width: textW + 4, height: pointSize * 2))

        let textX = centerX - textW * 0.5
        let textY = -(centerY + pointSize * 0.35)
        var ctx = context
        ctx.translateBy(x: textX, y: textY)
        for line in layoutManager.textLines {
            for run in line {
                for glyph in run {
                    ctx.draw(glyph)
                }
            }
        }
    }

    private func estimatedTextWidth(_ text: String, pointSize: Float) -> Float {
        Float(text.count) * pointSize * 0.55
    }

    private func resolvedPointSize() -> Float {
        environment.font.map { Float($0.pointSize) } ?? 14
    }

    private func resolvedFont() -> Font? {
        if let font = environment.font { return font }
        if unsafe RenderEngine.shared != nil { return .system(size: 14) }
        return nil
    }

    private func requestDisplay() {
        self.invalidateNearestLayer()
        self.owner?.containerView?.setNeedsDisplay(in: self.absoluteFrame())
    }
}

// MARK: - Tab Section Header

private struct TabSectionHeader: View, ViewNodeBuilder {
    typealias Body = Never
    var body: Never { fatalError() }
    let title: String

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TabSectionHeaderNode(content: self, inputs: context)
    }
}

private final class TabSectionHeaderNode: ViewNode {

    private var title: String

    init(content: TabSectionHeader, inputs: _ViewInputs) {
        self.title = content.title
        super.init(content: content)
        self.updateEnvironment(inputs.environment)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let width = proposal.width ?? TabViewConstants.tabBarWidth
        return Size(width: width, height: TabViewConstants.sectionHeaderHeight)
    }

    override func draw(with context: UIGraphicsContext) {
        var ctx = context
        ctx.environment = environment
        ctx.translateBy(x: frame.origin.x, y: -frame.origin.y)

        guard let font = resolvedFont() else { return }
        let pointSize = TabViewConstants.sectionHeaderFontSize
        var attributes = TextAttributeContainer()
        attributes.font = font
        attributes.foregroundColor = TabViewConstants.sectionHeaderColor
        let attributedText = AttributedText(title.uppercased(), attributes: attributes)
        let container = TextContainer(text: attributedText, textAlignment: .leading)
        let layoutManager = TextLayoutManager()
        layoutManager.setTextContainer(container)
        layoutManager.fitToSize(Size(width: frame.width, height: TabViewConstants.sectionHeaderHeight))

        let startX = TabViewConstants.tabHorizontalPadding
        let startY = -(frame.height * 0.5 + pointSize * 0.35)
        ctx.translateBy(x: startX, y: startY)
        for line in layoutManager.textLines {
            for run in line {
                for glyph in run {
                    ctx.draw(glyph)
                }
            }
        }
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? TabSectionHeaderNode else { return }
        self.title = other.title
    }

    private func resolvedFont() -> Font? {
        if unsafe RenderEngine.shared != nil {
            return .system(size: Double(TabViewConstants.sectionHeaderFontSize))
        }
        return nil
    }
}
