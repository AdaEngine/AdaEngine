//
//  ScrollView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public struct ScrollView<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never

    let axis: Axis
    let content: Content

    public init(_ axis: Axis = .vertical, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let node = ScrollViewViewNode(content: content, inputs: _ViewListInputs(input: inputs))
        node.axis = axis
        return node
    }
}

final class ScrollViewViewNode: ViewContainerNode {
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
