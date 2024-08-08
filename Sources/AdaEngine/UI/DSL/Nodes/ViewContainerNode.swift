//
//  ViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Observation
import Math

// FIXME: Check that container will handle ObservationTracking
// FIXME: Merging trees after rebuild can be broken

/// View node that can store children.
/// Most used for tuple, layout stacks and other containers.
///
/// When view did notify about changes, this container calls ``invalidateContent`` method to update it child and merge them if exists.
class ViewContainerNode: ViewNode {

    var nodes: [ViewNode]

    /// Virtual container nodes used to move their child from this nodes to another.
    var isVirtual: Bool = false

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

    /// Invalidate content with specific context.
    func invalidateContent(with inputs: _ViewListInputs) {
        guard let outputs = body?(inputs) else {
            return
        }

        let outputNodes = outputs.outputs.map { $0.node }
        self.updateChildNodes(from: outputNodes)
    }

    override func isEquals(_ otherNode: ViewNode) -> Bool {
        guard let containerNode = otherNode as? ViewContainerNode else {
            return super.isEquals(otherNode)
        }

        return self.nodes == containerNode.nodes
    }

    override func invalidateContent() {
        let inputs = _ViewInputs(
            parentNode: self,
            environment: self.environment
        )
        let listInputs = _ViewListInputs(input: inputs)
        self.invalidateContent(with: listInputs)
    }

    /// Compare and update old child nodes with a new nodes.
    private func updateChildNodes(from newNodes: [ViewNode]) {
        var needsLayout = false
        var allNewNodes = [ViewNode]()

        // Unfold new nodes if needed
        for node in newNodes {
            if let container = node as? ViewContainerNode, container.isVirtual {
                allNewNodes.append(contentsOf: container.nodes)

                continue
            }

            allNewNodes.append(node)
        }

        // We have same this, merge new nodes into old
        if self.nodes.count == allNewNodes.count {
            for (index, (oldNode, newNode)) in zip(self.nodes, allNewNodes).enumerated() {
                if newNode.canUpdate(oldNode) {
                    oldNode.update(from: newNode)
                } else {
                    self.nodes[index] = newNode
                    needsLayout = true
                }
            }
        } else {
            // has different sizes.
            let difference = allNewNodes.difference(from: self.nodes)
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

        for node in nodes {
            node.updateEnvironment(environment)

            if let owner = node.owner {
                node.updateViewOwner(owner)
            }
        }

        if shouldNotifyAboutChanges {
            self._printDebugNode()
        }

        if needsLayout {
            self.performLayout()
        }
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let container = newNode as? ViewContainerNode else {
            return
        }

        self.updateChildNodes(from: container.nodes)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        super.updateEnvironment(environment)

        for node in nodes {
            node.updateEnvironment(environment)
        }
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        for node in self.nodes {
            if let foundNode = node.findNodeById(id) {
                return foundNode
            }
        }

        return nil
    }
    
    override func buildMenu(with builder: any UIMenuBuilder) {
        for node in nodes {
            node.buildMenu(with: builder)
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

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        
        for node in nodes {
            node.updateViewOwner(owner)
        }
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
        string.append("\n\(indent)> nodes:")
        string.append(newValue)
        return string
    }
}
