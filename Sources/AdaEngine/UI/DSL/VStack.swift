//
//  VStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct VStack<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never

    let alignment: HorizontalAlignment
    let spacing: Float?
    let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
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
            layout: VStackLayout(alignment: self.alignment, spacing: self.spacing),
            content: content,
            nodes: outputs.map { $0.node }
        )
    }
}
