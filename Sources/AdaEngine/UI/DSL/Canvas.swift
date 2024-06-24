//
//  Canvas.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

/// A view type that supports immediate mode drawing.
public struct Canvas: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let drawBlock: (GUIRenderContext, Size) -> Void

    public init(drawBlock: @escaping (GUIRenderContext, Size) -> Void) {
        self.drawBlock = drawBlock
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        return CanvasWidgetNode(content: self, drawBlock: self.drawBlock)
    }

}
