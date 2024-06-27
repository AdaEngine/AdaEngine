//
//  ZStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct ZStack<Content: Widget>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let anchor: AnchorPoint
    let content: Content
    
    public init(anchor: AnchorPoint = .center, @WidgetBuilder content: () -> Content) {
        self.anchor = anchor
        self.content = content()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        let outputs = Content._makeListView(_WidgetGraphNode(value: content), inputs: _WidgetListInputs(input: context)).outputs

        return LayoutWidgetContainerNode(
            layout: ZStackLayout(anchor: self.anchor),
            content: content,
            nodes: outputs.map { $0.node }
        )
    }
}
