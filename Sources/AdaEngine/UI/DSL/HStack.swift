//
//  HStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct HStack<Content: Widget>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let alignment: VerticalAlignment
    let spacing: Float?
    let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Float? = nil,
        @WidgetBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        LayoutWidgetContainerNode(
            layout: HStackLayout(alignment: self.alignment, spacing: self.spacing),
            content: content,
            context: context
        )
    }
}
