//
//  WidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

protocol Layout {
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size
}

@MainActor
class WidgetNode {
    weak var parent: WidgetNode?

    var content: any Widget
    var storages: [UpdatablePropertyStorage] = []
    var frame: Rect = .zero

    // MARK: Layout
    
    var needsInvalidateNodes: Bool = true
    var needsLayout: Bool = false
    
    init(content: any Widget) {
        self.content = content
        print("Create node \(type(of: content))")
    }

    func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return frame.size
    }
    
    func performLayout() {
        
    }
    
    func invalidateContent() { }

    func draw(with context: GUIRenderContext) { }

    // MARK: - Debug
    
    func _printDebugNode() {
        dump(self)
    }
    
    // MARK: - Interaction
    
    func onReceiveEvent(_ event: InputEvent) {
        
    }

    func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
        return nil
    }

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    func point(inside point: Point, with event: InputEvent) -> Bool {
        return false
    }

    func convert(_ point: Point, to view: WidgetNode?) -> Point {
        return .zero
    }

    func convert(_ point: Point, from view: WidgetNode?) -> Point {
        return view?.convert(point, to: self) ?? point
    }
}

/// Used for tuple
class WidgetContainerNode: WidgetNode {
    
    typealias BuildContentBlock = () -> [WidgetNode]
    
    var nodes: [WidgetNode] = []
    let buildBlock: BuildContentBlock

    init(
        content: any Widget,
        buildNodesBlock: @escaping BuildContentBlock
    ) {
        self.buildBlock = buildNodesBlock
        super.init(content: content)

        self.invalidateContent()
    }

    override func performLayout() {
        for node in nodes {
            node.performLayout()
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        var size: Size = .zero
        
        for node in nodes {
            let childSize = node.sizeThatFits(proposal)
            size += childSize
        }

        return size
    }

    override func invalidateContent() {
        self.nodes = self.buildBlock()
        
        for node in nodes {
            node.parent = self
        }
    }

    override func draw(with context: GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        for node in self.nodes {
            node.draw(with: context)
        }

        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }
}

class WidgetStackContainerNode: WidgetContainerNode {
    
    enum StackAxis {
        case horizontal
        case vertical
        case depth
    }
    
    let axis: StackAxis
    let spacing: Float

    init(axis: StackAxis, spacing: Float, content: any Widget, buildNodesBlock: @escaping BuildContentBlock) {
        self.axis = axis
        self.spacing = spacing

        super.init(content: content, buildNodesBlock: buildNodesBlock)
    }
    
    override func performLayout() {
        if frame == .zero { return }

        let count = self.nodes.count
        var origin: Point = .zero

        for node in self.nodes {
            var size: Size = .zero

            switch axis {
            case .horizontal, .vertical:
                let proposalWidth = self.axis == .horizontal ? self.frame.width / Float(count) : self.frame.width
                let proposalHeight = self.axis == .vertical ? self.frame.height / Float(count) : self.frame.height
                let proposal = ProposedViewSize(
                    width: proposalWidth,
                    height: proposalHeight
                )

                size = node.sizeThatFits(proposal)
            case .depth:
                let proposal = ProposedViewSize(
                    width: frame.width,
                    height: frame.height
                )
                size = node.sizeThatFits(proposal)
            }

            node.frame.size = size
            node.frame.origin = origin

            node.performLayout()

            switch axis {
            case .horizontal:
                origin.x += spacing + size.width
            case .vertical:
                origin.y += spacing + size.height
            case .depth:
                continue
            }
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        super.sizeThatFits(proposal)
    }
}

class WidgetNodeVisibility: WidgetNode {
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?

    deinit {
        self.onDisappear?()
    }

    override func performLayout() {
        self.onAppear?()
    }
}
