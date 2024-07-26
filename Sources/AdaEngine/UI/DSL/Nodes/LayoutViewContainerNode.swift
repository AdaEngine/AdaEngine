//
//  LayoutViewContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

/// The container that can layout it childs with specific ``Layout``.
class LayoutViewContainerNode: ViewContainerNode {
    
    let layout: AnyLayout
    private var cache: AnyLayout.Cache?

    init<L: Layout, Content: View>(layout: L, content: Content, nodes: [ViewNode]) {
        self.layout = AnyLayout(layout)
        super.init(content: content, nodes: nodes)

        self.updateLayoutProperties(L.layoutProperties)
    }

    init<L: Layout, Content: View>(layout: L, content: @escaping () -> Content) {
        self.layout = AnyLayout(layout)
        super.init(content: content)
        self.updateLayoutProperties(L.layoutProperties)
    }

    init<L: Layout, Content: View>(layout: L, content: Content, body: @escaping (_ViewListInputs) -> _ViewListOutputs) {
        self.layout = AnyLayout(layout)
        super.init(content: content, body: body)
        self.updateLayoutProperties(L.layoutProperties)
    }

    override func performLayout() {
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
            in: Rect(origin: .zero, size: self.frame.size),
            proposal: ProposedViewSize(width: self.frame.width, height: self.frame.height),
            subviews: subviews,
            cache: &cache
        )

        self.cache = cache
    }

    override func invalidateContent() {
        var inputs = _ViewInputs(environment: self.environment)
        inputs.layout = self.layout
        let listInputs = _ViewListInputs(input: inputs)
        self.invalidateContent(with: listInputs)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
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
