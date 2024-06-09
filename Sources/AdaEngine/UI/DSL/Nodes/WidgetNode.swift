//
//  WidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
class WidgetNode {
    weak var parent: WidgetNode?
    
    var stackIndex: Int = 0
    var content: any Widget
    var storages: [UpdatablePropertyStorage] = []
    
    // MARK: Layout
    
    var needsInvalidateNodes: Bool = true
    var needsLayout: Bool = false
    
    init(
        parent: WidgetNode? = nil,
        stackIndex: Int,
        content: any Widget
    ) {
        self.parent = parent
        self.stackIndex = stackIndex
        self.content = content
    }
    
    func layout(parentUsesSize: Bool = false) {
        
    }
    
    func performLayout() {
        
    }
    
    func invalidateContent() {
        
    }
    
    func renderNode(context: GUIRenderContext) {
        
    }
    
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

class RectangleWidgetNode: WidgetNode {
    
    var rect: Rect
    
    init(rect: Rect,
         parent: WidgetNode? = nil,
         stackIndex: Int,
         content: any Widget
    ) {
        self.rect = rect
        super.init(parent: parent, stackIndex: stackIndex, content: content)
    }
}

/// Used for tuple
class WidgetContainerNode: WidgetNode {
    
    typealias BuildContentBlock = () -> [WidgetNode]
    
    var nodes: [WidgetNode] = []
    let buildBlock: BuildContentBlock
    
    init(
        parent: WidgetNode? = nil, 
        stackIndex: Int,
        content: any Widget,
        buildNodesBlock: @escaping BuildContentBlock
    ) {
        self.buildBlock = buildNodesBlock
        super.init(parent: parent, stackIndex: stackIndex, content: content)
    }
    
    override func invalidateContent() {
        self.nodes = self.buildBlock()
        
        for node in nodes {
            node.parent = self
        }
        
        print(nodes)
    }
}

class WidgetStackContainerNode: WidgetContainerNode {
    
    enum StackAxis {
        case horizontal
        case vertical
        case depth
    }
    
    let axis: StackAxis
    
    init(axis: StackAxis, content: any Widget, buildNodesBlock: @escaping BuildContentBlock) {
        self.axis = axis
        
        super.init(stackIndex: 0, content: content, buildNodesBlock: buildNodesBlock)
    }
    
    override func performLayout() {
        
    }
}

class WidgetNodeVisibility: WidgetNode {
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?
}
