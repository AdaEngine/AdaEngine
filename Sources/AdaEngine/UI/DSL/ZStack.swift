//
//  ZStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct ZStack<Content: View>: View {

    public typealias Body = Never

    let anchor: AnchorPoint
    let content: Content
    
    public init(anchor: AnchorPoint = .center, @ViewBuilder content: () -> Content) {
        self.anchor = anchor
        self.content = content()
    }

    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let content = view[\.content]
        let stack = view.value

        let nodes = Content._makeListView(content, inputs: _ViewListInputs(input: inputs)).outputs.map { $0.node }
        let node = LayoutViewContainerNode(
            layout: ZStackLayout(anchor: stack.anchor),
            content: view.value,
            nodes: nodes
        )

        return _ViewOutputs(node: node)
    }
}
