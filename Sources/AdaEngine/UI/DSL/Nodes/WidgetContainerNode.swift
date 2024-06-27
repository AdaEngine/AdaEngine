//
//  WidgetContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

/// Base container for children nodes.
/// Most used for tuple, layout stacks and other containers.
class WidgetContainerNode: WidgetNode {
    
    var nodes: [WidgetNode]

    init<Content: Widget>(content: Content, nodes: [WidgetNode]) {
        self.nodes = nodes
        super.init(content: content)

        for node in nodes {
            node.parent = self
        }
    }

    init<Content: Widget>(content: Content, inputs: _WidgetListInputs) {
        let nodes = Content._makeListView(_WidgetGraphNode(value: content), inputs: inputs).outputs.map { $0.node }
        self.nodes = nodes
        super.init(content: content)

        for node in nodes {
            node.parent = self
        }
    }

    override init<Content>(content: Content) where Content : Widget {
        self.nodes = []
        super.init(content: content)
    }

    override func invalidateContent() {
//        let context = _WidgetInputs(environment: self.environment)
//
//        let node = builder.makeWidgetNode(context: context)
//
//        let nodes: [WidgetNode]
//
//        if let container = node as? WidgetTransportContainerNode {
//            nodes = container.nodes
//        } else {
//            nodes = [node]
//        }
//        self.nodes = nodes
//
//        for node in nodes {
//            node.parent = self
//            node.updateEnvironment(self.environment)
//        }
    }

    override func updateEnvironment(_ environment: WidgetEnvironmentValues) {
        super.updateEnvironment(environment)

        for node in nodes {
            node.updateEnvironment(environment)
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
