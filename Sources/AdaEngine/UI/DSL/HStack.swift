//
//  HStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct HStack<Content: View>: View, ViewNodeBuilder {

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
    
    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let outputs = Content._makeListView(_ViewGraphNode(value: content), inputs: _ViewListInputs(input: inputs)).outputs

        return LayoutViewContainerNode(
            layout: HStackLayout(alignment: self.alignment, spacing: self.spacing),
            content: content,
            nodes: outputs.map { $0.node }
        )
    }
}
