//
//  LayoutViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

import Math

/// The container that can layout it childs with specific ``Layout``.
class LayoutViewContainerNode: ViewContainerNode {
    
    let layout: AnyLayout
    private let inherentLayoutProperties: LayoutProperties
    private var cache: AnyLayout.Cache?

    private var shouldBypassLayout: Bool {
        nodes.count == 1 && inherentLayoutProperties.stackOrientation == nil
    }

    init<L: Layout, Content: View>(layout: L, content: Content, nodes: [ViewNode]) {
        self.layout = AnyLayout(layout)
        self.inherentLayoutProperties = L.layoutProperties
        super.init(content: content, nodes: nodes)
        super.updateLayoutProperties(inherentLayoutProperties)
    }

    init<L: Layout, Content: View>(layout: L, content: @escaping () -> Content) {
        self.layout = AnyLayout(layout)
        self.inherentLayoutProperties = L.layoutProperties
        super.init(content: content)
        super.updateLayoutProperties(inherentLayoutProperties)
    }

    init<L: Layout, Content: View>(layout: L, content: Content, body: @escaping (_ViewListInputs) -> _ViewListOutputs) {
        self.layout = AnyLayout(layout)
        self.inherentLayoutProperties = L.layoutProperties
        super.init(content: content, body: body)
        super.updateLayoutProperties(inherentLayoutProperties)
    }

    override func updateLayoutProperties(_ props: LayoutProperties) {
        let resolvedProps = inherentLayoutProperties.stackOrientation == nil ? props : inherentLayoutProperties
        super.updateLayoutProperties(resolvedProps)
    }

    override func performLayout() {
        performLayout(
            in: Rect(origin: .zero, size: self.frame.size),
            proposal: ProposedViewSize(width: self.frame.width, height: self.frame.height)
        )
    }

    /// Perform layout with custom bounds and proposal.
    /// Subclasses like ``ScrollViewNode`` use this to place children within
    /// the content area instead of the visible frame.
    func performLayout(in bounds: Rect, proposal: ProposedViewSize) {
        if shouldBypassLayout, let node = self.nodes.first {
            node.place(in: bounds.origin, anchor: .topLeading, proposal: proposal)
            self.invalidateLayerIfNeeded()
            return
        }

        let subviews = LayoutSubviews(self.nodes.map { LayoutSubview(node: $0) })

        if var cache = self.cache {
            layout.updateCache(&cache, subviews: subviews)
            self.cache = cache
        } else {
            self.cache = layout.makeCache(subviews: subviews)
        }

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
        self.invalidateContent(with: listInputs)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if shouldBypassLayout, let node = self.nodes.first {
            return node.sizeThatFits(proposal)
        }

        let subviews = LayoutSubviews(self.nodes.map { LayoutSubview(node: $0) })
        if var cache = self.cache {
            layout.updateCache(&cache, subviews: subviews)
            self.cache = cache
        } else {
            self.cache = layout.makeCache(subviews: subviews)
        }

        guard var cache else {
            return proposal.replacingUnspecifiedDimensions()
        }

        return layout.sizeThatFits(proposal, subviews: subviews, cache: &cache)
    }
}
