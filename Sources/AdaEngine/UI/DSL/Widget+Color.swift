//
//  Widget+Color.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

extension Color: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    @MainActor
    func makeWidgetNode(context: Context) -> WidgetNode {
        return CanvasWidgetNode(content: self, drawBlock: { context, size in
            context.drawRect(Rect(origin: .zero, size: size), color: self)
        })
    }
}
