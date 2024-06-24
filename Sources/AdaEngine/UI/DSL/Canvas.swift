//
//  Canvas.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

import Math

/// A view type that supports immediate mode drawing.
public struct Canvas: Widget, WidgetNodeBuilder {

    public typealias RenderBlock = (GUIRenderContext, Size) -> Void

    public typealias Body = Never

    let render: RenderBlock

    public init(render: @escaping RenderBlock) {
        self.render = render
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        return CanvasWidgetNode(content: self, drawBlock: self.render)
    }
}

@MainActor
class CanvasWidgetNode: WidgetNode {

    let drawBlock: Canvas.RenderBlock

    init<Content: Widget>(content: Content, drawBlock: @escaping Canvas.RenderBlock) {
        self.drawBlock = drawBlock
        super.init(content: content)
    }

    override func draw(with context: GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        self.drawBlock(context, self.frame.size)

        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }
}
