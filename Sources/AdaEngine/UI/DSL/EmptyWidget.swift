//
//  EmptyWidget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

public struct EmptyWidget: Widget, WidgetNodeBuilder {
    public typealias Body = Never

    func makeWidgetNode(context: Context) -> WidgetNode {
        WidgetNode(content: self)
    }
}
