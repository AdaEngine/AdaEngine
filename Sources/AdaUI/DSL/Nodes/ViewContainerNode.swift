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
import Foundation

/// View node that can store children.
/// Most used for tuple, layout stacks and other containers.
///
/// When view did notify about changes, this container calls ``invalidateContent`` method to update it child and merge them if exists.
class ViewContainerNode: ViewNode {

    var nodes: [ViewNode]

    /// Virtual container nodes used to move their child from this nodes to another.
    var isVirtual: Bool = false

    override var transientEnvironmentChildren: [ViewNode] {
        nodes
    }

    /// Builder method returns a new children.
    private var body: ((_ViewListInputs) -> _ViewListOutputs)?
    private var hasScheduledObservedContentInvalidation = false
    private var hasBuiltContent = false
    private var hasDeferredInitialContentBuild = false

    private static var observationTrackingDepth = 0

    init<Content: View>(content: Content, nodes: [ViewNode]) {
        self.nodes = nodes
        self.body = { [content] inputs in
            return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs)
        }
        super.init(content: content)

        for node in nodes {
            node.parent = self
        }
    }

    /// Supports observation
    init<Content: View>(content: @escaping () -> Content) {
        self.nodes = []
        super.init(content: content())
        self.body = { inputs in
            let content = content()
            return Content._makeListView(_ViewGraphNode(value: content), inputs: inputs)
        }
    }

    init<Content>(
        content: Content,
        buildImmediately: Bool = true,
        body: @escaping (_ViewListInputs) -> _ViewListOutputs
    ) where Content: View {
        self.nodes = []
        self.body = body
        super.init(content: content)

        if buildImmediately {
            self.invalidateContent()
        }
    }

    /// Invalidate content with specific context.
    func invalidateContent(with inputs: _ViewListInputs, propagateLayout: Bool = true) {
        guard let body = self.body else {
            return
        }

        guard !deferInitialContentBuildIfNeeded() else {
            return
        }

        hasBuiltContent = true
        UILayoutDebugCounters.recordContentInvalidation()
        UILayoutDebugCounters.recordRebuild()
        ViewContainerNode.observationTrackingDepth += 1
        let outputs = withObservationTracking {
            body(inputs)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.scheduleObservedContentInvalidation()
            }
        }
        ViewContainerNode.observationTrackingDepth -= 1

        let outputNodes = outputs.outputs.map { $0.node }
        self.reconcileChildNodes(from: outputNodes, propagateLayout: propagateLayout)
    }

    private func scheduleObservedContentInvalidation() {
        guard !hasScheduledObservedContentInvalidation else {
            return
        }

        hasScheduledObservedContentInvalidation = true
        Task { @MainActor in
            self.hasScheduledObservedContentInvalidation = false
            self.invalidateContent(propagateLayout: false)
        }
    }

    private func deferInitialContentBuildIfNeeded() -> Bool {
        guard !hasBuiltContent,
              !isVirtual,
              !(content is any AnyViewTuple),
              ViewContainerNode.observationTrackingDepth > 0 else {
            return false
        }

        guard !hasDeferredInitialContentBuild else {
            return true
        }

        hasDeferredInitialContentBuild = true
        return true
    }

    func flushDeferredInitialContentBuildIfNeeded() {
        guard hasDeferredInitialContentBuild, !hasBuiltContent else {
            return
        }

        hasDeferredInitialContentBuild = false
        invalidateContent()
    }

    override func isEquals(_ otherNode: ViewNode) -> Bool {
        guard otherNode is ViewContainerNode else {
            return super.isEquals(otherNode)
        }

        return super.isEquals(otherNode)
    }

    override func invalidateContent() {
        self.invalidateContent(propagateLayout: true)
    }

    override func invalidateContent(propagateLayout: Bool) {
        let inputs = _ViewInputs(
            parentNode: self,
            environment: self.environment
        )
        let listInputs = _ViewListInputs(input: inputs)
        if propagateLayout {
            self.invalidateContent(with: listInputs)
            self.markNeedsLayout()
            self.invalidateNearestLayer()
            owner?.containerView?.setNeedsLayout()
            return
        }

        Self.withSuppressedLayoutPropagation {
            self.invalidateContent(with: listInputs, propagateLayout: false)
        }

        self.markNeedsLayout(propagateToParent: false)
        self.invalidateNearestLayer()
        owner?.containerView?.setNeedsLayout(in: visualAbsoluteFrame())
    }

    /// Compare and update old child nodes with a new nodes.
    func reconcileChildNodes(from newNodes: [ViewNode], propagateLayout: Bool = true) {
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

        let oldNodes = self.nodes
        let reconciliation = self.reconcileNodesById(allNewNodes)
            ?? self.reconcileNodesByStructuralPosition(oldNodes: oldNodes, newNodes: allNewNodes)

        for oldNode in oldNodes where !reconciliation.reusedNodeIDs.contains(ObjectIdentifier(oldNode)) {
            oldNode.parent = nil
        }

        self.nodes = reconciliation.nodes

        let currentOwner = self.owner
        for node in nodes {
            node.updateLayoutProperties(layoutProperties)

            if let currentOwner, node.owner !== currentOwner {
                node.updateViewOwner(currentOwner)
            }
        }

        if shouldNotifyAboutChanges {
//            self._printDebugNode()
        }

        if !oldNodes.isEmpty || !allNewNodes.isEmpty {
            self.markNeedsLayout(propagateToParent: propagateLayout)
        }
    }

    private struct Reconciliation {
        var nodes: [ViewNode]
        var reusedNodeIDs: Set<ObjectIdentifier>
    }

    private func reconcileNodesById(_ newNodes: [ViewNode]) -> Reconciliation? {
        var oldNodesById: [AnyHashable: ViewNode] = [:]
        var oldIdCounts: [AnyHashable: Int] = [:]
        var oldNodesWithoutId: [ViewNode] = []

        for node in self.nodes {
            if let id = nodeIdentity(node) {
                oldIdCounts[id, default: 0] += 1
                if oldIdCounts[id] == 1 {
                    oldNodesById[id] = node
                } else {
                    oldNodesById[id] = nil
                }
            } else {
                oldNodesWithoutId.append(node)
            }
        }

        guard !oldNodesById.isEmpty, newNodes.contains(where: { nodeIdentity($0) != nil }) else {
            return nil
        }

        let newNodesWithoutId = newNodes.filter { nodeIdentity($0) == nil }
        let unkeyedReconciliation = self.reconcileNodesByStructuralPosition(
            oldNodes: oldNodesWithoutId,
            newNodes: newNodesWithoutId
        )
        var unkeyedNodesByNewNodeID: [ObjectIdentifier: ViewNode] = [:]
        for (newNode, resolvedNode) in zip(newNodesWithoutId, unkeyedReconciliation.nodes) {
            unkeyedNodesByNewNodeID[ObjectIdentifier(newNode)] = resolvedNode
        }

        var reconciledNodes: [ViewNode] = []
        reconciledNodes.reserveCapacity(newNodes.count)
        var reusedNodeIDs = unkeyedReconciliation.reusedNodeIDs

        for newNode in newNodes {
            if let id = nodeIdentity(newNode), let oldNode = oldNodesById.removeValue(forKey: id) {
                if newNode.canUpdate(oldNode) {
                    reconciledNodes.append(reuse(oldNode, with: newNode))
                    reusedNodeIDs.insert(ObjectIdentifier(oldNode))
                } else {
                    reconciledNodes.append(prepareNewNode(newNode))
                }
                continue
            }

            if let resolvedNode = unkeyedNodesByNewNodeID[ObjectIdentifier(newNode)] {
                reconciledNodes.append(resolvedNode)
            } else {
                reconciledNodes.append(prepareNewNode(newNode))
            }
        }

        return Reconciliation(nodes: reconciledNodes, reusedNodeIDs: reusedNodeIDs)
    }

    private func reconcileNodesByStructuralPosition(
        oldNodes: [ViewNode],
        newNodes: [ViewNode]
    ) -> Reconciliation {
        var resolvedNodes = Array<ViewNode?>(repeating: nil, count: newNodes.count)
        var reusedNodeIDs = Set<ObjectIdentifier>()

        var prefixEnd = 0
        while prefixEnd < oldNodes.count,
              prefixEnd < newNodes.count,
              newNodes[prefixEnd].canUpdate(oldNodes[prefixEnd]) {
            let oldNode = oldNodes[prefixEnd]
            resolvedNodes[prefixEnd] = reuse(oldNode, with: newNodes[prefixEnd])
            reusedNodeIDs.insert(ObjectIdentifier(oldNode))
            prefixEnd += 1
        }

        var oldSuffixIndex = oldNodes.count - 1
        var newSuffixIndex = newNodes.count - 1
        while oldSuffixIndex >= prefixEnd,
              newSuffixIndex >= prefixEnd,
              newNodes[newSuffixIndex].canUpdate(oldNodes[oldSuffixIndex]) {
            let oldNode = oldNodes[oldSuffixIndex]
            resolvedNodes[newSuffixIndex] = reuse(oldNode, with: newNodes[newSuffixIndex])
            reusedNodeIDs.insert(ObjectIdentifier(oldNode))
            oldSuffixIndex -= 1
            newSuffixIndex -= 1
        }

        if prefixEnd <= newSuffixIndex {
            for index in prefixEnd...newSuffixIndex where resolvedNodes[index] == nil {
                resolvedNodes[index] = prepareNewNode(newNodes[index])
            }
        }

        return Reconciliation(
            nodes: resolvedNodes.map { $0! },
            reusedNodeIDs: reusedNodeIDs
        )
    }

    private func nodeIdentity(_ node: ViewNode) -> AnyHashable? {
        return (node as? IDViewNodeModifier)?.identifier
    }

    private func reuse(_ oldNode: ViewNode, with newNode: ViewNode) -> ViewNode {
        oldNode.update(from: newNode)
        oldNode.parent = self
        return oldNode
    }

    private func prepareNewNode(_ newNode: ViewNode) -> ViewNode {
        newNode.parent = self
        newNode.markInspectionRedraw()
        return newNode
    }

    override func didMove(to parent: ViewNode?) {
        super.didMove(to: parent)
        if parent == nil {
            for node in nodes {
                node.parent = nil
            }
        }
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let container = newNode as? ViewContainerNode else {
            return
        }

        self.body = container.body
        if self.stateContainer != nil || container.nodes.isEmpty {
            if Self.isLayoutPropagationSuppressed {
                self.invalidateContent(propagateLayout: false)
            } else {
                self.invalidateContent()
            }
            return
        }

        self.reconcileChildNodes(from: container.nodes)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        // Only cascade to children when this node's environment actually changed.
        // super.updateEnvironment applies environmentTransform and skips storing if the
        // resulting version is unchanged — so comparing prevVersion detects no-ops cheaply.
        guard self.environment.version != prevVersion else { return }
        for node in nodes {
            // Pass self.environment (post-transform) so children inherit the correct base.
            node.updateEnvironment(self.environment)
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
        let previousProps = layoutProperties
        super.updateLayoutProperties(props)
        guard previousProps != layoutProperties else {
            return
        }

        for node in nodes {
            node.updateLayoutProperties(props)
        }
    }

    override func performLayout() {
        let center = Point(x: frame.width * 0.5, y: frame.height * 0.5)
        let proposal = ProposedViewSize(frame.size)

        for node in nodes {
            node.place(in: center, anchor: .center, proposal: proposal)
        }
    }

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
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
        flushDeferredInitialContentBuildIfNeeded()
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
        flushDeferredInitialContentBuildIfNeeded()
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

    override func drawInspectionChildLayoutBounds(with context: UIGraphicsContext) {
        for node in nodes {
            node.drawInspectionLayoutBounds(with: context)
        }
    }

    override func drawInspectionChildRedrawFlashes(
        with context: UIGraphicsContext,
        baselineRevision: UInt64
    ) {
        for node in nodes {
            node.drawInspectionRedrawFlashes(
                with: context,
                baselineRevision: baselineRevision
            )
        }
    }

    override func drawInspectionChildSelectionBounds(
        with context: UIGraphicsContext,
        mode: UIDebugOverlayMode,
        focusedNode: ViewNode?,
        hitTestNode: ViewNode?
    ) {
        for node in nodes {
            node.drawInspectionSelectionBounds(
                with: context,
                mode: mode,
                focusedNode: focusedNode,
                hitTestNode: hitTestNode
            )
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
