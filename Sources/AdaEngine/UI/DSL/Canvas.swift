//
//  Canvas.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

public struct Canvas: Widget, WidgetNodeBuilder {

    let drawBlock: (GUIRenderContext, Rect) -> Void

    public init(drawBlock: @escaping (GUIRenderContext, Rect) -> Void) {
        self.drawBlock = drawBlock
    }

    public var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        return CanvasWidgetNode(content: self, drawBlock: self.drawBlock)
    }

}
