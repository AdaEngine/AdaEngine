//
//  WidgetContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

/// Used for tuple and other containers
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

    override func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        var size: Size = .zero

        for node in nodes {
            let childSize = node.sizeThatFits(proposal, usedByParent: usedByParent)
            size += childSize
        }

        if usedByParent {
            return size
        } else {
            return Size(
                width: min(size.width, proposal.width ?? 0),
                height: min(size.height, proposal.height ?? 0)
            )
        }
    }

    override func invalidateContent() {
        self.nodes = self.buildBlock()

        for node in nodes {
            node.parent = self
        }
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
        for node in self.nodes.reversed() {
            let newPoint = node.convert(point, from: self)
            if let node = node.hitTest(newPoint, with: event) {
                return node
            }
        }

        return super.hitTest(point, with: event)
    }

    override func draw(with context: GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        for node in self.nodes {
            node.draw(with: context)
        }

        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }

    override func debugDescription(hierarchy: Int = 0, identation: Int = 2) -> String {
        let indent = String(repeating: " ", count: hierarchy * identation)
        var string = super.debugDescription(hierarchy: hierarchy)
        let newValue = self.nodes.reduce(into: indent, { partialResult, node in
            partialResult += "\n" + node.debugDescription(hierarchy: hierarchy + 1, identation: identation)
        })
        string.append("\n\(indent)- nodes:")
        string.append(newValue)
        return string
    }
}
