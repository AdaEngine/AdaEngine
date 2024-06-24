//
//  ScrollView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public struct ScrollView<Content: Widget>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let axis: Axis
    let content: Content

    public init(_ axis: Axis = .vertical, @WidgetBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = ScrollViewWidgetNode(content: content, context: context)
        node.axis = axis
        return node
    }
}

final class ScrollViewWidgetNode: WidgetContainerNode {
    var axis: Axis = .vertical
    private var bounds: Rect = .zero

    override func performLayout() {
        super.performLayout()
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if axis == .vertical {

        } else {
            
        }
    }
}
