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

@MainActor @preconcurrency
public struct TabContainer<Selection: Hashable, Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let labels: [String]
    let values: [Selection]
    let selection: Binding<Selection>
    let content: (Selection) -> Content

    public init(
        _ tabs: [(label: String, value: Selection)],
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping (Selection) -> Content
    ) {
        self.labels = tabs.map(\.label)
        self.values = tabs.map(\.value)
        self.selection = selection
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TabContainerNode(inputs: context, container: self)
    }
}

public extension TabContainer where Selection == Int {
    init(
        _ labels: [String],
        selection: Binding<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.labels = labels
        self.values = Array(labels.indices)
        self.selection = selection
        self.content = content
    }
}

// MARK: - Constants

private enum TabContainerConstants {
    static var tabBarHeight: Float { 40 }
    static var tabHorizontalPadding: Float { 20 }
    static var tabSpacing: Float { 0 }
    static var tabBarBottomBorder: Float { 2 }
    static var selectedIndicatorHeight: Float { 3 }

    static var tabTextColor: Color { .fromHex(0x666666) }
    static var selectedTabTextColor: Color { .fromHex(0xF0F0F0) }
    static var indicatorColor: Color { .fromHex(0xFF2D6F) }
    static var borderColor: Color { .fromHex(0x2A2A2A) }
}

// MARK: - Node

final class TabContainerNode<Selection: Hashable, Content: View>: ViewNode {

    private var labels: [String]
    private var values: [Selection]
    private var selectionBinding: Binding<Selection>
    private var contentBuilder: (Selection) -> Content
    private var viewInputs: _ViewInputs

    private var tabBarNode: LayoutViewContainerNode
    private var contentNode: ViewNode

    init(inputs: _ViewInputs, container: TabContainer<Selection, Content>) {
        self.labels = container.labels
        self.values = container.values
        self.selectionBinding = container.selection
        self.contentBuilder = container.content
        self.viewInputs = inputs

        let selected = container.selection.wrappedValue
        self.tabBarNode = Self.buildTabBar(
            labels: container.labels,
            values: container.values,
            selected: selected,
            inputs: inputs,
            onSelect: { _ in }
        )
        self.contentNode = Self.buildContent(
            for: selected,
            builder: container.content,
            inputs: inputs
        )

        super.init(content: container)

        self.tabBarNode.parent = self
        self.contentNode.parent = self

        let weakSelf = Weak(self)
        self.tabBarNode = Self.buildTabBar(
            labels: container.labels,
            values: container.values,
            selected: selected,
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
        let tabBarSize = tabBarNode.sizeThatFits(
            ProposedViewSize(width: width, height: TabContainerConstants.tabBarHeight)
        )
        let contentProposal = ProposedViewSize(
            width: width,
            height: proposal.height.map { max(0, $0 - tabBarSize.height) }
        )
        let contentSize = contentNode.sizeThatFits(contentProposal)

        return Size(
            width: max(tabBarSize.width, contentSize.width),
            height: tabBarSize.height + contentSize.height
        )
    }

    override func performLayout() {
        let tabBarProposal = ProposedViewSize(
            width: frame.width,
            height: TabContainerConstants.tabBarHeight
        )
        tabBarNode.place(
            in: Point(x: frame.width * 0.5, y: TabContainerConstants.tabBarHeight * 0.5),
            anchor: .center,
            proposal: tabBarProposal
        )

        let contentHeight = max(0, frame.height - TabContainerConstants.tabBarHeight)
        let contentProposal = ProposedViewSize(width: frame.width, height: contentHeight)
        contentNode.place(
            in: Point(x: frame.width * 0.5, y: TabContainerConstants.tabBarHeight + contentHeight * 0.5),
            anchor: .center,
            proposal: contentProposal
        )
    }

    override func update(from newNode: ViewNode) {
        guard let other = newNode as? TabContainerNode<Selection, Content> else {
            return
        }

        self.labels = other.labels
        self.values = other.values
        self.selectionBinding = other.selectionBinding
        self.contentBuilder = other.contentBuilder
        self.viewInputs = other.viewInputs

        super.update(from: other)
        rebuildAll()
    }

    override func invalidateContent() {
        rebuildAll()
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        super.updateEnvironment(environment)
        tabBarNode.updateEnvironment(environment)
        contentNode.updateEnvironment(environment)
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        tabBarNode.updateViewOwner(owner)
        contentNode.updateViewOwner(owner)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        let tabBarPoint = tabBarNode.convert(point, from: self)
        if let hit = tabBarNode.hitTest(tabBarPoint, with: event) {
            return hit
        }

        let contentPoint = contentNode.convert(point, from: self)
        return contentNode.hitTest(contentPoint, with: event)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)

        tabBarNode.draw(with: context)

        let borderY = -TabContainerConstants.tabBarHeight
        context.drawLine(
            start: Point(0, borderY),
            end: Point(frame.width, borderY),
            lineWidth: TabContainerConstants.tabBarBottomBorder,
            color: TabContainerConstants.borderColor
        )

        contentNode.draw(with: context)
    }

    override func update(_ deltaTime: TimeInterval) {
        tabBarNode.update(deltaTime)
        contentNode.update(deltaTime)
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        tabBarNode.findNodeById(id) ?? contentNode.findNodeById(id)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        if let result = super.findNodyByAccessibilityIdentifier(identifier) {
            return result
        }
        return tabBarNode.findNodyByAccessibilityIdentifier(identifier)
            ?? contentNode.findNodyByAccessibilityIdentifier(identifier)
    }

    // MARK: - Private

    private func selectTab(_ value: Selection) {
        guard selectionBinding.wrappedValue != value else {
            return
        }
        selectionBinding.wrappedValue = value
        rebuildAll()
    }

    private func rebuildAll() {
        let selected = selectionBinding.wrappedValue

        let weakSelf = Weak(self)
        let newTabBar = Self.buildTabBar(
            labels: labels,
            values: values,
            selected: selected,
            inputs: viewInputs,
            onSelect: { value in
                weakSelf.value?.selectTab(value)
            }
        )

        tabBarNode.update(from: newTabBar)
        tabBarNode.parent = self
        if let owner {
            tabBarNode.updateViewOwner(owner)
        }
        tabBarNode.updateEnvironment(environment)

        let newContent = Self.buildContent(
            for: selected,
            builder: contentBuilder,
            inputs: viewInputs
        )

        contentNode.parent = nil
        contentNode = newContent
        contentNode.parent = self
        if let owner {
            contentNode.updateViewOwner(owner)
        }
        contentNode.updateEnvironment(environment)

        self.invalidateNearestLayer()
        if let containerView = self.owner?.containerView {
            containerView.setNeedsDisplay(in: self.absoluteFrame())
        }
        self.performLayout()
    }

    private static func buildTabBar(
        labels: [String],
        values: [Selection],
        selected: Selection,
        inputs: _ViewInputs,
        onSelect: @escaping (Selection) -> Void
    ) -> LayoutViewContainerNode {
        let tabBarView = HStack(alignment: .center, spacing: TabContainerConstants.tabSpacing) {
            ForEach(0..<labels.count, id: \.self) { index in
                TabButton(
                    label: labels[index],
                    isSelected: values[index] == selected,
                    action: {
                        onSelect(values[index])
                    }
                )
            }
        }

        let output = HStack._makeView(
            _ViewGraphNode(value: tabBarView),
            inputs: inputs
        )
        let node = output.node as! LayoutViewContainerNode
        return node
    }

    private static func buildContent(
        for selection: Selection,
        builder: @escaping (Selection) -> Content,
        inputs: _ViewInputs
    ) -> ViewNode {
        let view = builder(selection)
        return Content._makeView(_ViewGraphNode(value: view), inputs: inputs).node
    }
}

// MARK: - Tab Button

private struct TabButton: View, ViewNodeBuilder {
    typealias Body = Never
    var body: Never { fatalError() }

    let label: String
    let isSelected: Bool
    let action: () -> Void

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TabButtonNode(content: self, inputs: context)
    }
}

private final class TabButtonNode: ViewNode {

    private var label: String
    private var isSelected: Bool
    private var action: () -> Void
    private var isHighlighted: Bool = false

    init(content: TabButton, inputs: _ViewInputs) {
        self.label = content.label
        self.isSelected = content.isSelected
        self.action = content.action
        super.init(content: content)
        self.updateEnvironment(inputs.environment)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let pointSize = resolvedPointSize()
        let textWidth = Float(label.count) * pointSize * 0.55
        let width = textWidth + TabContainerConstants.tabHorizontalPadding * 2
        let height = proposal.height ?? TabContainerConstants.tabBarHeight
        return Size(width: width, height: height)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }
        return self
    }

    override func onMouseEvent(_ event: MouseEvent) {
        switch event.phase {
        case .began, .changed:
            isHighlighted = true
        case .ended:
            let wasHighlighted = isHighlighted
            isHighlighted = false
            if wasHighlighted {
                action()
            }
        case .cancelled:
            isHighlighted = false
        }
        requestDisplay()
    }

    override func onMouseLeave() {
        isHighlighted = false
        requestDisplay()
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)

        let bounds = Rect(x: 0, y: 0, width: frame.width, height: frame.height)

        if isHighlighted {
            context.drawRect(bounds, color: Color.fromHex(0x1A1A1A))
        }

        let pointSize = resolvedPointSize()
        let textWidth = Float(label.count) * pointSize * 0.55
        let textColor = isSelected
            ? TabContainerConstants.selectedTabTextColor
            : TabContainerConstants.tabTextColor

        if let font = resolvedFont() {
            var attributes = TextAttributeContainer()
            attributes.font = font
            attributes.foregroundColor = textColor
            let attributedText = AttributedText(label, attributes: attributes)

            let container = TextContainer(
                text: attributedText,
                textAlignment: .center
            )
            let layoutManager = TextLayoutManager()
            layoutManager.setTextContainer(container)
            layoutManager.fitToSize(Size(width: bounds.width, height: bounds.height))

            let textX = (bounds.width - textWidth) * 0.5
            let textY = -bounds.height * 0.5 - pointSize * 0.35
            context.translateBy(x: textX, y: textY)
            for line in layoutManager.textLines {
                for run in line {
                    for glyph in run {
                        context.draw(glyph)
                    }
                }
            }
            context.translateBy(x: -textX, y: -textY)
        }

        if isSelected {
            let indicatorY = -bounds.height
            let indicatorHeight = TabContainerConstants.selectedIndicatorHeight
            context.drawRect(
                Rect(x: 0, y: indicatorY, width: bounds.width, height: indicatorHeight),
                color: TabContainerConstants.indicatorColor
            )
        }
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? TabButtonNode else {
            return
        }
        self.label = other.label
        self.isSelected = other.isSelected
        self.action = other.action
    }

    private func resolvedPointSize() -> Float {
        if let font = environment.font {
            return Float(font.pointSize)
        }
        return 14
    }

    private func resolvedFont() -> Font? {
        if let font = environment.font {
            return font
        }
        if unsafe RenderEngine.shared != nil {
            return .system(size: 14)
        }
        return nil
    }

    private func requestDisplay() {
        self.invalidateNearestLayer()
        self.owner?.containerView?.setNeedsDisplay(in: self.absoluteFrame())
    }
}

// MARK: - Weak helper

private struct Weak<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}
