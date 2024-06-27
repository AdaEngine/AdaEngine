//
//  Layout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

public struct Axis: OptionSet {
    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let horizontal = Axis(rawValue: 1 << 0)
    public static let vertical = Axis(rawValue: 1 << 1)
}

/// Layout-specific properties of a layout container.
public struct LayoutProperties {
    /// The orientation of the containing stack-like container.
    var stackOrientation: Axis?

    public init(stackOrientation: Axis? = nil) {
        self.stackOrientation = stackOrientation
    }
}

@MainActor
public protocol Layout {
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews

    func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size

    func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)

    func updateCache(_ cache: inout Cache, subviews: Subviews)

    func makeCache(subviews: Subviews) -> Cache

    /// Properties of a layout container.
    static var layoutProperties: LayoutProperties { get }
}

public extension Layout {
    func updateCache(_ cache: inout Cache, subviews: Subviews) { }

    static var layoutProperties: LayoutProperties { LayoutProperties() }
}

public extension Layout where Cache == Void {
    func makeCache(subviews: Subviews) -> Cache {
        return
    }
}

extension Layout {
    public func callAsFunction<Content: Widget>(@WidgetBuilder _ content: @escaping () -> Content) -> some Widget {
        CustomLayoutContainer(layout: self, content: content())
    }
}

// MARK: - Internal

struct CustomLayoutContainer<T: Layout, Content: Widget>: Widget, WidgetNodeBuilder {

    typealias Body = Never

    let layout: T
    let content: Content

    func makeWidgetNode(context: Context) -> WidgetNode {
        let outputs = Content._makeListView(_WidgetGraphNode(value: content), inputs: _WidgetListInputs(input: context)).outputs

        return LayoutWidgetContainerNode(
            layout: context.layout,
            content: content,
            nodes: outputs.map { $0.node }
        )
    }
}

final class LayoutWidgetContainerNode: WidgetContainerNode {
    let layout: AnyLayout
    private var cache: AnyLayout.Cache?
    private var subviews: LayoutSubviews = LayoutSubviews([])

    init<L: Layout, Content: Widget>(layout: L, content: Content, nodes: [WidgetNode]) {
        self.layout = AnyLayout(layout)
        super.init(content: content, nodes: nodes)

        self.updateLayoutProperties(L.layoutProperties)
        self.subviews = LayoutSubviews(self.nodes.map { LayoutSubview(node: $0) })
    }

    override func performLayout() {
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

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if var cache = self.cache {
            layout.updateCache(&cache, subviews: subviews)
            self.cache = cache
        } else {
            self.cache = layout.makeCache(subviews: subviews)
        }

        guard var cache else {
            return proposal.replacingUnspecifiedDimensions()
        }

        return layout.sizeThatFits(proposal, subviews: self.subviews, cache: &cache)
    }
}
