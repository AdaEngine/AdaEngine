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
    let content: () -> Content

    public init(_ axis: Axis = .vertical, @ViewBuilder content: @escaping () -> Content) {
        self.axis = axis
        self.content = content
    }

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let node = ScrollViewNode(content: content)
        node.axis = self.axis
        node.updateEnvironment(inputs.environment)
        node.invalidateContent(with: _ViewListInputs(input: inputs))

        return node
    }
}

final class ScrollViewNode: ViewContainerNode {
    var axis: Axis = .vertical
    private var bounds: Rect = .zero

    override func performLayout() {
        let center = Point(x: bounds.midX, y: bounds.midY)
        let proposal = ProposedViewSize(frame.size)

        for node in nodes {
            node.place(in: center, anchor: .top, proposal: proposal)
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let size = super.sizeThatFits(proposal)
        return size
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if axis == .vertical {

        } else {
            
        }
    }
}
