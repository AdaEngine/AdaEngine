//
//  LayoutViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

import Math
import AdaUtils

/// The container that can layout it childs with specific ``Layout``.
class LayoutViewContainerNode: ViewContainerNode {
    
    let layout: AnyLayout
    private let inherentLayoutProperties: LayoutProperties
    private let bypassSingleChildLayout: Bool
    private var cache: AnyLayout.Cache?
    private var cacheNeedsUpdate = true

    private var shouldBypassLayout: Bool {
        bypassSingleChildLayout && nodes.count == 1
    }

    init<L: Layout, Content: View>(
        layout: L,
        content: Content,
        nodes: [ViewNode],
        bypassSingleChildLayout: Bool = false
    ) {
        self.layout = AnyLayout(layout)
        self.inherentLayoutProperties = L.layoutProperties
        self.bypassSingleChildLayout = bypassSingleChildLayout
        super.init(content: content, nodes: nodes)
        super.updateLayoutProperties(inherentLayoutProperties)
    }

    init<L: Layout, Content: View>(
        layout: L,
        content: @escaping () -> Content,
        bypassSingleChildLayout: Bool = false
    ) {
        self.layout = AnyLayout(layout)
        self.inherentLayoutProperties = L.layoutProperties
        self.bypassSingleChildLayout = bypassSingleChildLayout
        super.init(content: content)
        super.updateLayoutProperties(inherentLayoutProperties)
    }

    init<L: Layout, Content: View>(
        layout: L,
        content: Content,
        bypassSingleChildLayout: Bool = false,
        body: @escaping (_ViewListInputs) -> _ViewListOutputs
    ) {
        self.layout = AnyLayout(layout)
        self.inherentLayoutProperties = L.layoutProperties
        self.bypassSingleChildLayout = bypassSingleChildLayout
        super.init(content: content, body: body)
        super.updateLayoutProperties(inherentLayoutProperties)
    }

    override func updateLayoutProperties(_ props: LayoutProperties) {
        let resolvedProps = inherentLayoutProperties.stackOrientation == nil ? props : inherentLayoutProperties
        super.updateLayoutProperties(resolvedProps)
        cacheNeedsUpdate = true
    }

    override func performLayout() {
        if shouldBypassLayout, let node = nodes.first {
            let center = Point(x: frame.width * 0.5, y: frame.height * 0.5)
            let proposal = ProposedViewSize(frame.size)
            node.place(in: center, anchor: .center, proposal: proposal)
            self.invalidateLayerIfNeeded()
            return
        }

        performLayout(
            in: Rect(origin: .zero, size: self.frame.size),
            proposal: ProposedViewSize(width: self.frame.width, height: self.frame.height)
        )
    }

    /// Perform layout with custom bounds and proposal.
    /// Subclasses like ``ScrollViewNode`` use this to place children within
    /// the content area instead of the visible frame.
    func performLayout(in bounds: Rect, proposal: ProposedViewSize) {
        let subviews = LayoutSubviews(self.nodes.map { LayoutSubview(node: $0) })
        ensureCache(for: subviews)

        guard var cache else {
            return
        }

        layout.placeSubviews(
            in: bounds,
            proposal: proposal,
            subviews: subviews,
            cache: &cache
        )

        self.cache = cache
        self.invalidateLayerIfNeeded()
    }

    override func invalidateContent() {
        var inputs = _ViewInputs(parentNode: self, environment: self.environment)
        inputs.layout = self.layout
        let listInputs = _ViewListInputs(input: inputs)
        cacheNeedsUpdate = true
        self.invalidateContent(with: listInputs)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if shouldBypassLayout, let node = nodes.first {
            return node.sizeThatFits(proposal)
        }

        let subviews = LayoutSubviews(self.nodes.map { LayoutSubview(node: $0) })
        ensureCache(for: subviews)

        guard var cache else {
            return proposal.replacingUnspecifiedDimensions()
        }

        return layout.sizeThatFits(proposal, subviews: subviews, cache: &cache)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        let prevVersion = self.environment.version
        super.updateEnvironment(environment)
        if self.environment.version != prevVersion {
            cacheNeedsUpdate = true
        }
    }

    override func update(from newNode: ViewNode) {
        cacheNeedsUpdate = true
        super.update(from: newNode)
    }

    private func ensureCache(for subviews: LayoutSubviews) {
        if cache == nil {
            cache = layout.makeCache(subviews: subviews)
            cacheNeedsUpdate = false
            return
        }

        guard cacheNeedsUpdate, var cache else {
            return
        }

        layout.updateCache(&cache, subviews: subviews)
        self.cache = cache
        cacheNeedsUpdate = false
    }
}
