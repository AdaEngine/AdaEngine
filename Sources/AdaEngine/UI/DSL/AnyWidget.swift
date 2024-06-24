//
//  AnyWidget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public struct AnyWidget: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let content: any Widget

    public init<T: Widget>(_ widget: T) {
        self.content = widget
    }

    public init(_ widget: any Widget) {
        self.content = widget
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        if let builder = WidgetNodeBuilderUtils.findNodeBuilder(in: content) {
            return builder.makeWidgetNode(context: context)
        } else {
            return WidgetNode(content: content)
        }
    }
}
