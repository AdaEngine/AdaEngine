//
//  ZStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct ZStack<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never

    let anchor: AnchorPoint
    let content: Content
    
    public init(anchor: AnchorPoint = .center, @ViewBuilder content: () -> Content) {
        self.anchor = anchor
        self.content = content()
    }
    
    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let outputs = Content._makeListView(_ViewGraphNode(value: content), inputs: _ViewListInputs(input: inputs)).outputs

        return LayoutViewContainerNode(
            layout: ZStackLayout(anchor: self.anchor),
            content: content,
            nodes: outputs.map { $0.node }
        )
    }
}
