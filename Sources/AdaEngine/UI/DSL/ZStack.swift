//
//  ZStack.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct ZStack<Content: Widget>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let spacing: Float
    let content: Content
    
    public init(spacing: Float = 0, @WidgetBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        LayoutWidgetContainerNode(
            layout: ZStackLayout(),
            content: content,
            context: context
        )
    }
}
