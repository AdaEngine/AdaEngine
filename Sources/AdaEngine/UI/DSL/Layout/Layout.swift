//
//  Layout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

/// Layout-specific properties of a layout container.
public struct LayoutProperties {
    /// The orientation of the containing stack-like container.
    var stackOrientation: Axis?

    public init(stackOrientation: Axis? = nil) {
        self.stackOrientation = stackOrientation
    }
}

public protocol Layout {
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews

    @MainActor(unsafe)
    func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size

    @MainActor(unsafe)
    func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)

    @MainActor(unsafe)
    func updateCache(_ cache: inout Cache, subviews: Subviews)

    @MainActor(unsafe)
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
    public func callAsFunction<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        CustomLayoutContainer(layout: self, content: content())
    }
}

// MARK: - Internal

struct CustomLayoutContainer<T: Layout, Content: View>: View {

    typealias Body = Never

    let layout: T
    let content: Content

    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let content = view[\.content]
        let layout = AnyLayout(view[\.layout].value)

        var inputs = inputs
        inputs.layout = layout

        let nodes = Content._makeListView(content, inputs: _ViewListInputs(input: inputs)).outputs.map { $0.node }

        let node = LayoutViewContainerNode(
            layout: layout,
            content: view.value,
            nodes: nodes
        )

        return _ViewOutputs(node: node)
    }
}
