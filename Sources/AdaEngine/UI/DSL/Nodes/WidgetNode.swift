//
//  WidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

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
    }

    func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        var newSize = self.frame.size

        if let width = proposal.width {
            if width == .infinity {
                newSize.width = self.parent?.frame.width ?? 0
            } else {
                newSize.width = width
            }
        }

        if let height = proposal.height {
            if height == .infinity {
                newSize.height = self.parent?.frame.height ?? 0
            } else {
                newSize.height = height
            }
        }

        return newSize
    }
    
    func performLayout() {
        
    }
    
    func invalidateContent() { }

    func draw(with context: GUIRenderContext) { }

    // MARK: - Debug
    
    func _printDebugNode() {
        print(self.debugDescription(hierarchy: 0))
    }
    
    // MARK: - Interaction
    
    func onReceiveEvent(_ event: InputEvent) {
        
    }

    func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
        if self.point(inside: point, with: event) {
            return self
        }

        return nil
    }

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.frame.contains(point: point)
    }

    func convert(_ point: Point, to node: WidgetNode?) -> Point {
        guard let node, node !== self else {
            return point
        }

        if node.parent === self {
            return (point - node.frame.origin)
        } else if let parent, parent === node {
            return point + frame.origin
        }
        
        return point
    }

    func convert(_ point: Point, from node: WidgetNode?) -> Point {
        return node?.convert(point, to: self) ?? point
    }

    open func onTouchesEvent(_ touches: Set<TouchEvent>) {

    }

    open func onMouseEvent(_ event: MouseEvent) {

    }

    func debugDescription(hierarchy: Int = 0, identation: Int = 2) -> String {
        let identation = String(repeating: " ", count: hierarchy * identation)
        return """
        \(identation)\(type(of: self)):
        \(identation)\(identation)- frame: \(frame)
        \(identation)\(identation)- content: \(type(of: self.content))
        """
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
