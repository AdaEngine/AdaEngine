//
//  ViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Observation
import Math

/// View node that can store children.
/// Most used for tuple, layout stacks and other containers.
///
/// When view did notify about changes, this container calls ``invalidateContent`` method to update it child and merge them if exists.
class ViewContainerNode: ViewNode {

     var nodes: [ViewNode]

    /// Builder method returns a new children.
    private var body: ((_ViewListInputs) -> _ViewListOutputs)?

    init<Content: View>(content: Content, nodes: [ViewNode]) {
        self.nodes = nodes
        self.body = { inputs in return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs) }
        super.init(content: content)

        for node in nodes {
            node.parent = self
        }
    }

    /// Supports observation
    init<Content: View>(content: @escaping () -> Content) {
        self.nodes = []
        super.init(content: content())
        self.body = { [weak self] inputs in
            guard let self else {
                return _ViewListOutputs(outputs: [])
            }

            let content = withObservationTracking(content) {
                Task { @MainActor in
                    self.invalidateContent()
                }
            }
            return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs)
        }
    }

    init<Content>(content: Content, body: @escaping (_ViewListInputs) -> _ViewListOutputs) where Content : View {
        self.nodes = []
        self.body = body
        super.init(content: content)

        self.invalidateContent()
    }

    func invalidateContent(with inputs: _ViewListInputs) {
        guard let outputs = body?(inputs) else {
            return
        }

        let outputNodes = outputs.outputs.map { $0.node }

        // We have same this, merge new nodes into old

        if self.nodes == outputNodes {
            for (oldNode, newNode) in zip(self.nodes, outputNodes) {
                oldNode.merge(newNode)
            }
        } else {
            // has different sizes.
            let difference = outputNodes.difference(from: self.nodes)

            for change in difference {
                switch change {
                case let .remove(index, _, _):
                    self.nodes.remove(at: index)
                case let .insert(index, newElement, _):
                    newElement.parent = self
                    self.nodes.insert(newElement, at: index)
                }
            }
        }

        for node in nodes {
            node.updateEnvironment(environment)
        }

        if shouldNotifyAboutChanges {
            self._printDebugNode()
        }

        self.performLayout()
    }

    override func isEquals(_ otherNode: ViewNode) -> Bool {
        guard let containerNode = otherNode as? ViewContainerNode else {
            return super.isEquals(otherNode)
        }

        return self.nodes == containerNode.nodes
    }

    override func invalidateContent() {
        let inputs = _ViewInputs(environment: self.environment)
        let listInputs = _ViewListInputs(input: inputs)
        self.invalidateContent(with: listInputs)
    }

    override func merge(_ otherNode: ViewNode) {
        super.merge(otherNode)

        guard let container = otherNode as? ViewContainerNode else {
            return
        }

        var needsLayout = false

        // We have same this, merge new nodes into old
        if self.nodes.count == container.nodes.count {
            for (index, (oldNode, newNode)) in zip(self.nodes, container.nodes).enumerated() {
                if type(of: oldNode) == type(of: newNode) {
                    oldNode.merge(newNode)
                } else {
                    self.nodes[index] = newNode
                    needsLayout = true
                }
            }
        } else {
            // has different sizes.
            let difference = container.nodes.difference(from: self.nodes)

            for change in difference {
                switch change {
                case let .remove(index, _, _):
                    self.nodes.remove(at: index)
                case let .insert(index, newElement, _):
                    newElement.parent = self
                    self.nodes.insert(newElement, at: index)
                }
            }

            needsLayout = true
        }

        if needsLayout {
            self.performLayout()
        }
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
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

    override func update(_ deltaTime: TimeInterval) async {
        for node in nodes {
            await node.update(deltaTime)
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

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        for node in self.nodes {
            node.draw(with: context)
        }
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
