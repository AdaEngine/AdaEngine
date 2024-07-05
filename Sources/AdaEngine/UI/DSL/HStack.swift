//
//  HStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct HStack<Content: View>: View {

    public typealias Body = Never

    let alignment: VerticalAlignment
    let spacing: Float?
    let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Float? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    
    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let content = view[\.content]
        let stack = view.value

        let nodes = Content._makeListView(content, inputs: _ViewListInputs(input: inputs)).outputs.map { $0.node }
        let node = LayoutViewContainerNode(
            layout: HStackLayout(alignment: stack.alignment, spacing: stack.spacing),
            content: view.value,
            nodes: nodes
        )

        return _ViewOutputs(node: node)
    }
}
