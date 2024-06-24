//
//  WidgetContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

/// Used for tuple and other containers
class WidgetContainerNode: WidgetNode {
    
    var nodes: [WidgetNode]

    init<Content: Widget>(content: Content, nodes: [WidgetNode]) {
        self.nodes = nodes
        super.init(content: content)

        self.storages = WidgetNodeBuilderUtils.findPropertyStorages(in: content, node: self)

        for node in nodes {
            node.parent = self
        }
    }

    init<Content: Widget>(content: Content, context: WidgetNodeBuilderContext) {
        guard let builder = WidgetNodeBuilderUtils.findNodeBuilder(in: content) else {
            fatalError("Can't find builder")
        }

        let node = builder.makeWidgetNode(context: context)

        let nodes: [WidgetNode]

        if let container = node as? WidgetTransportContainerNode {
            nodes = container.nodes
        } else {
            nodes = [node]
        }

        self.nodes = nodes
        super.init(content: content)

        self.storages = WidgetNodeBuilderUtils.findPropertyStorages(in: content, node: self)

        for node in nodes {
            node.parent = self
        }
    }

    override func updateLayoutProperties(_ props: LayoutProperties) {
        super.updateLayoutProperties(props)

        for node in nodes {
            node.updateLayoutProperties(props)
        }
    }

    override func performLayout() {
        let center = Point(x: frame.midX, y: frame.midY)
        let proposal = ProposedViewSize(frame.size)

        for node in nodes {
            node.place(in: center, anchor: .center, proposal: proposal)
        }
    }

    override func update(_ deltaTime: TimeInterval) {
        for node in nodes {
            node.update(deltaTime)
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let size = proposal.replacingUnspecifiedDimensions()
        return nodes.reduce(size) { result, node in
            let size = node.sizeThatFits(proposal)
            return Size(width: max(result.width, size.width), height: max(result.height, size.height))
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

        for node in self.nodes where node.frame.intersects(self.frame) {
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
