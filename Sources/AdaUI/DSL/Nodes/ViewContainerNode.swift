//
//  ViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import AdaApp
import AdaInput
import AdaUtils
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
        self.invalidateNearestLayer()
    }

    // swiftlint:disable cyclomatic_complexity
    /// Compare and update old child nodes with a new nodes.
    private func updateChildNodes(from newNodes: [ViewNode]) {
        var needsLayout = false
        var allNewNodes = [ViewNode]()
        allNewNodes.reserveCapacity(newNodes.count)

        // Unfold new nodes if needed
        for node in newNodes {
            if let container = node as? ViewContainerNode, container.isVirtual {
                allNewNodes.append(contentsOf: container.nodes)

                continue
            }

            allNewNodes.append(node)
        }

        // We have same count, merge new nodes into old by index.
        if let reconciled = self.reconcileNodesById(allNewNodes) {
            self.nodes = reconciled
            needsLayout = true
        } else if self.nodes.count == allNewNodes.count {
            for (index, (oldNode, newNode)) in zip(self.nodes, allNewNodes).enumerated() {
                if newNode.canUpdate(oldNode) {
                    oldNode.update(from: newNode)
                    oldNode.parent = self
                    needsLayout = true
                } else {
                    newNode.parent = self
                    self.nodes[index] = newNode
                    needsLayout = true
                }
            }
        } else {
            // Different count: keep reconciliation linear and avoid expensive CollectionDifference.
            let oldCount = self.nodes.count
            let newCount = allNewNodes.count
            let sharedCount = min(oldCount, newCount)

            if sharedCount > 0 {
                for index in 0..<sharedCount {
                    let oldNode = self.nodes[index]
                    let newNode = allNewNodes[index]

                    if newNode.canUpdate(oldNode) {
                        oldNode.update(from: newNode)
                        oldNode.parent = self
                    } else {
                        newNode.parent = self
                        self.nodes[index] = newNode
                    }
                }
            }

            if oldCount > newCount {
                self.nodes.removeLast(oldCount - newCount)
            } else if newCount > oldCount {
                for index in oldCount..<newCount {
                    let newNode = allNewNodes[index]
                    newNode.parent = self
                    self.nodes.append(newNode)
                }
            }

            needsLayout = true
        }

        let currentOwner = self.owner
        for node in nodes {
            node.updateEnvironment(environment)

            if let currentOwner, node.owner !== currentOwner {
                node.updateViewOwner(currentOwner)
            }
        }

        if shouldNotifyAboutChanges {
            self._printDebugNode()
        }

        if needsLayout {
            self.performLayout()
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func reconcileNodesById(_ newNodes: [ViewNode]) -> [ViewNode]? {
        var oldNodesById: [AnyHashable: ViewNode] = [:]
        var oldNodesWithoutId: [ViewNode] = []

        for node in self.nodes {
            if let id = nodeIdentity(node) {
                oldNodesById[id] = node
            } else {
                oldNodesWithoutId.append(node)
            }
        }

        guard !oldNodesById.isEmpty, newNodes.contains(where: { nodeIdentity($0) != nil }) else {
            return nil
        }

        var reconciledNodes: [ViewNode] = []
        reconciledNodes.reserveCapacity(newNodes.count)

        var fallbackIndex = 0
        for newNode in newNodes {
            if let id = nodeIdentity(newNode), let oldNode = oldNodesById.removeValue(forKey: id) {
                if newNode.canUpdate(oldNode) {
                    oldNode.update(from: newNode)
                    oldNode.parent = self
                    reconciledNodes.append(oldNode)
                } else {
                    newNode.parent = self
                    reconciledNodes.append(newNode)
                }
                continue
            }

            if fallbackIndex < oldNodesWithoutId.count {
                let oldNode = oldNodesWithoutId[fallbackIndex]
                fallbackIndex += 1

                if newNode.canUpdate(oldNode) {
                    oldNode.update(from: newNode)
                    oldNode.parent = self
                    reconciledNodes.append(oldNode)
                } else {
                    newNode.parent = self
                    reconciledNodes.append(newNode)
                }
            } else {
                newNode.parent = self
                reconciledNodes.append(newNode)
            }
        }

        return reconciledNodes
    }

    private func nodeIdentity(_ node: ViewNode) -> AnyHashable? {
        return (node as? IDViewNodeModifier)?.identifier
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

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        if let node = super.findNodyByAccessibilityIdentifier(identifier) {
            return node
        }
        
        for node in self.nodes {
            if let foundNode = node.findNodyByAccessibilityIdentifier(identifier) {
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

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
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
        // NOTE: Dirty-rect drawing must be paired with clipping/scissor.
        // Without clipping, drawing a large background that intersects dirtyRect can
        // overwrite the whole surface while other nodes are skipped, causing "disappearing" UI.
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
