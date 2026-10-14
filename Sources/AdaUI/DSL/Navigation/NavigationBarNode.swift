import AdaInput
import AdaText
import AdaUtils
import Math

final class NavigationBarNode: ViewNode {
    private enum Constants {
        static let height: Float = 92
        static let horizontalPadding: Float = 16
        static let itemSpacing: Float = 10
        static let controlHeight: Float = 44
        static let titleHorizontalInset: Float = 72
        static let leadingTitleOffset: Float = 54
        static let minimumCenteredTitleWidth: Float = 120
    }

    private var configuration: NavigationBarConfiguration
    private var leadingItems: NavigationBarItemContent?
    private var trailingItems: NavigationBarItemContent?
    private var splitBackAction: NavigationSplitCompactBackAction?
    private var showsBackButton: Bool
    private weak var navigationContext: NavigationContext?
    private var inputs: _ViewInputs

    private var titleNode: ViewNode?
    private var splitBackButtonNode: ViewNode?
    private var backButtonNode: ViewNode?
    private var leadingItemsNode: ViewNode?
    private var trailingItemsNode: ViewNode?

    private var chromeTopInset: Float {
        max(0, environment.navigationBarChromeInsets.top)
    }

    var resolvedBackgroundColor: Color {
        configuration.navigationBarColor ?? .black
    }

    init(
        configuration: NavigationBarConfiguration,
        leadingItems: NavigationBarItemContent?,
        trailingItems: NavigationBarItemContent?,
        splitBackAction: NavigationSplitCompactBackAction?,
        showsBackButton: Bool,
        navigationContext: NavigationContext,
        inputs: _ViewInputs
    ) {
        self.configuration = configuration
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.splitBackAction = splitBackAction
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
        splitBackAction: NavigationSplitCompactBackAction?,
        showsBackButton: Bool,
        inputs: _ViewInputs
    ) {
        self.configuration = configuration
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.splitBackAction = splitBackAction
        self.showsBackButton = showsBackButton
        self.inputs = inputs
        rebuildChildren()
        updateEnvironment(inputs.environment)
        performLayout()
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        Size(width: proposal.width ?? 0,
            height: environment.navigationBarControlsAxis == .vertical ? proposal.height ?? Constants.height : chromeTopInset + Constants.height)
    }

    override func performLayout() {
        if environment.navigationBarControlsAxis == .vertical {
            performDockedControlsLayout()
            return
        }
        let titlePosition = resolvedTitlePosition()
        let centerY = chromeTopInset + Constants.height * 0.5
        let sides = environment.navigationContentSideInsets
        var leadingX = Constants.horizontalPadding + sides.leading
        let reservedTitleWidth =
            titlePosition == .center || titlePosition == .automatic
            ? Constants.minimumCenteredTitleWidth
            : 0
        let maxItemWidth = max(
            0,
            (frame.width - sides.leading - sides.trailing - Constants.horizontalPadding * 2 - reservedTitleWidth - Constants.itemSpacing * 2) * 0.5
        )

        if let splitBackButtonNode {
            splitBackButtonNode.place(
                in: Point(x: leadingX, y: centerY),
                anchor: .leading,
                proposal: ProposedViewSize(width: Constants.controlHeight, height: Constants.controlHeight)
            )
            leadingX += Constants.controlHeight + Constants.itemSpacing
        }

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
                in: Point(x: frame.width - sides.trailing - Constants.horizontalPadding, y: centerY),
                anchor: .trailing,
                proposal: ProposedViewSize(width: trailingWidth, height: Constants.controlHeight)
            )
        }

        if let titleNode {
            switch titlePosition {
            case .leading:
                let availableWidth = max(0, frame.width - sides.trailing - leadingX - trailingWidth - Constants.horizontalPadding - Constants.itemSpacing)
                titleNode.place(
                    in: Point(x: leadingX, y: centerY),
                    anchor: .leading,
                    proposal: ProposedViewSize(width: availableWidth, height: Constants.controlHeight)
                )
            case .automatic,
                .center:
                let occupiedSideWidth = max(
                    leadingX - sides.leading,
                    Constants.horizontalPadding + trailingWidth + Constants.itemSpacing
                )
                titleNode.place(
                    in: Point(x: sides.leading + (frame.width - sides.leading - sides.trailing) * 0.5, y: centerY),
                    anchor: .center,
                    proposal: ProposedViewSize(
                        width: max(0, frame.width - sides.leading - sides.trailing - occupiedSideWidth * 2),
                        height: Constants.controlHeight
                    )
                )
            }
        }
    }

    private func performDockedControlsLayout() {
        let isLeading = environment.resolvedNavigationBarControlsPlacement == .leading
        let sides = environment.navigationContentSideInsets
        let inset = isLeading ? sides.leading : sides.trailing
        let centerX = isLeading ? inset * 0.5 : frame.width - inset * 0.5
        let range = environment.sideControlVerticalRange(in: absoluteFrame(), leading: isLeading)
        let nodes = [splitBackButtonNode, backButtonNode, trailingItemsNode].compactMap { $0 }
        let heights: [Float] = nodes.map { max(Constants.controlHeight, $0.sizeThatFits(ProposedViewSize(width: max(44, inset - 12), height: nil)).height) }
        let totalHeight: Float = heights.reduce(0 as Float, +) + Float(max(0, nodes.count - 1)) * Constants.itemSpacing
        let preferredTop = max(range.lowerBound + 16, environment.navigationBarControlsTopInset)
        var y = max(range.lowerBound, min(preferredTop, range.upperBound - totalHeight - 12))
        for (node, height) in zip(nodes, heights) {
            let measured = node.sizeThatFits(ProposedViewSize(width: max(44, inset - 12), height: nil))
            node.place(in: Point(centerX, y), anchor: .top,
                proposal: ProposedViewSize(width: max(Constants.controlHeight, min(measured.width, inset - 12)), height: height))
            y += height + Constants.itemSpacing
        }
        let centerY = chromeTopInset + Constants.height * 0.5
        var x = Constants.horizontalPadding + sides.leading
        if let leadingItemsNode {
            let size = leadingItemsNode.sizeThatFits(.unspecified)
            leadingItemsNode.place(in: Point(x, centerY), anchor: .leading,
                proposal: ProposedViewSize(width: size.width, height: Constants.controlHeight))
            x += size.width + Constants.itemSpacing
        }
        titleNode?.place(in: Point(x, centerY), anchor: .leading,
            proposal: ProposedViewSize(width: max(0, frame.width - sides.trailing - x - Constants.horizontalPadding), height: Constants.controlHeight))
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        guard self.environment.version != prevVersion else {
            return
        }
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
        guard self.point(inside: point, with: event) else {
            return nil
        }
        for node in childNodes.reversed() {
            let childPoint = node.convert(point, from: self)
            if let hit = node.hitTest(childPoint, with: event) {
                return hit
            }
        }
        return nil
    }

    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        super.point(inside: point, with: event)
            || childNodes.contains { node in
                let childPoint = node.convert(point, from: self)
                return node.point(inside: childPoint, with: event)
            }
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        let navigationBarColor = resolvedBackgroundColor
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)
        context.drawLinearGradient(
            ResolvedLinearGradient(
                startPoint: .top,
                endPoint: .bottom,
                stops: [
                    Gradient.Stop(color: navigationBarColor.opacity(0.98), location: 0),
                    Gradient.Stop(color: navigationBarColor.opacity(0.72), location: 0.48),
                    Gradient.Stop(color: navigationBarColor.opacity(0), location: 1),
                ]
            ),
            in: Rect(origin: .zero, size: Size(width: frame.width, height: chromeTopInset + Constants.height))
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
        } else {
            for node in childNodes { node.parent = self }
        }
    }

    private var childNodes: [ViewNode] {
        [
            titleNode,
            splitBackButtonNode,
            backButtonNode,
            leadingItemsNode,
            trailingItemsNode,
        ]
        .compactMap { $0 }
    }

    var inspectionChildNodes: [ViewNode] {
        childNodes
    }

    private func rebuildChildren() {
        for node in childNodes {
            node.parent = nil
        }

        titleNode = makeTitleNode()
        splitBackButtonNode = splitBackAction.map(makeSplitBackButtonNode)
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
        guard let title = configuration.title, !title.isEmpty else {
            return nil
        }
        let pointSize: Double = resolvedTitlePosition() == .leading ? 22 : 16
        let view = Text(title)
            .font(configuration.titleFont ?? .system(size: pointSize))
            .foregroundColor(.white)
            .lineLimit(1)
        let node = Text._makeView(_ViewGraphNode(value: view), inputs: inputs).node
        node.accessibilityIdentifier = "AdaUI.NavigationBar.Title"
        return node
    }

    private func makeSplitBackButtonNode(action: NavigationSplitCompactBackAction) -> ViewNode {
        let view = Button(action: {
            action.perform()
        }, label: {
            NavigationBackButtonIcon()
                .frame(width: Constants.controlHeight, height: Constants.controlHeight)
        })
        let node = Button._makeView(_ViewGraphNode(value: view), inputs: navigationBarItemInputs()).node
        node.accessibilityIdentifier = "AdaUI.NavigationSplitView.backButton"
        return node
    }

    private func makeBackButtonNode() -> ViewNode {
        let view = Button(action: { [weak navigationContext] in
            navigationContext?.pop()
        }, label: {
            NavigationBackButtonIcon()
                .frame(width: Constants.controlHeight, height: Constants.controlHeight)
        })
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
        splitBackButtonNode?.updateEnvironment(itemEnvironment)
        backButtonNode?.updateEnvironment(itemEnvironment)
        leadingItemsNode?.updateEnvironment(itemEnvironment)
        trailingItemsNode?.updateEnvironment(itemEnvironment)
    }

    private func resolvedTitlePosition() -> NavigationTitlePosition {
        switch configuration.titlePosition {
        case .leading,
            .center:
            return configuration.titlePosition
        case .automatic:
            switch configuration.titleDisplayMode {
            case .large:
                return .leading
            case .automatic,
                .inline:
                return .center
            }
        }
    }
}
