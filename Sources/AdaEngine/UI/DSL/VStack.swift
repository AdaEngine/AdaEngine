//
//  VStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct VStack<Content: Widget>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let alignment: HorizontalAlignment
    let spacing: Float?
    let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Float? = nil,
        @WidgetBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        let outputs = Content._makeListView(_WidgetGraphNode(value: content), inputs: _WidgetListInputs(input: context)).outputs

        return LayoutWidgetContainerNode(
            layout: VStackLayout(alignment: self.alignment, spacing: self.spacing),
            content: content,
            nodes: outputs.map { $0.node }
        )
    }
}
