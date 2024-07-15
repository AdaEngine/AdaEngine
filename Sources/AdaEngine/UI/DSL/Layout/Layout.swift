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

@MainActor
@preconcurrency
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
    public func callAsFunction<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        CustomLayoutContainer(layout: self, content: content)
    }
}

// MARK: - Internal

struct CustomLayoutContainer<T: Layout, Content: View>: View {

    typealias Body = Never

    let layout: T
    let content: () -> Content

    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let content = view[\.content]
        let layout = AnyLayout(view[\.layout].value)

        var inputs = inputs
        inputs.layout = layout
        let node = LayoutViewContainerNode(layout: layout, content: content.value)

        return _ViewOutputs(node: node)
    }
}
