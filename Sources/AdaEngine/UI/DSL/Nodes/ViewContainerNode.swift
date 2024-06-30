//
//  ViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

/// Base container for children nodes.
/// Most used for tuple, layout stacks and other containers.
class ViewContainerNode: ViewNode {

    var nodes: [ViewNode]
    let body: (_ViewListInputs) -> _ViewListOutputs

    init<Content: View>(content: Content, nodes: [ViewNode]) {
        self.nodes = nodes
        self.body = { inputs in return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs) }
        super.init(content: content)

        for node in nodes {
            node.parent = self
        }
    }

    init<Content: View>(content: Content, inputs: _ViewListInputs) {
        self.body = { inputs in return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs) }
        self.nodes = []
        super.init(content: content)
        self.updateEnvironment(inputs.input.environment)
        self.invalidateContent()
    }

    override init<Content>(content: Content) where Content : View {
        self.nodes = []
        self.body = { inputs in return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs) }
        super.init(content: content)

        self.invalidateContent()
    }

    override func invalidateContent() {
        let inputs = _ViewInputs(environment: self.environment)
        let listInputs = _ViewListInputs(input: inputs)
        let outputs = body(listInputs)

        let outputNodes = outputs.outputs.map { $0.node }

        // We have same this, merge new nodes into old
        if self.nodes.count == outputNodes.count {
            for (oldNode, newNode) in zip(self.nodes, outputNodes) {
                oldNode.merge(newNode)
            }
        } else {
            // has different sizes.
            let difference = outputNodes.difference(from: self.nodes)

            for change in difference {
                switch change {
                case let .remove(index, _, oldIndex):
                    self.nodes.remove(at: index)
                case let .insert(index, newElement, _):
                    newElement.parent = self
                    self.nodes.insert(newElement, at: index)
                }
            }

            self.performLayout()
        }

        if shouldNotifyAboutChanges {
            self._printDebugNode()
        }
    }

    override func merge(_ otherNode: ViewNode) {
        guard let container = otherNode as? ViewContainerNode else {
            return
        }

        super.merge(container)

        // We have same this, merge new nodes into old
        if self.nodes.count == container.nodes.count {
            for (oldNode, newNode) in zip(self.nodes, container.nodes) {
                oldNode.merge(newNode)
            }
        } else {
            // has different sizes.
            let difference = container.nodes.difference(from: self.nodes)

            for change in difference {
                switch change {
                case let .remove(index, _, oldIndex):
                    self.nodes.remove(at: index)
                case let .insert(index, newElement, _):
                    newElement.parent = self
                    self.nodes.insert(newElement, at: index)
                }
            }

            self.performLayout()
        }
    }

    override func updateEnvironment(_ environment: ViewEnvironmentValues) {
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

    override func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
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
