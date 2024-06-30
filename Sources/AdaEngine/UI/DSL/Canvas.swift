//
//  Canvas.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

import Math

/// A view type that supports immediate mode drawing.
public struct Canvas: View, ViewNodeBuilder {

    public typealias RenderBlock = (GUIRenderContext, Size) -> Void

    public typealias Body = Never

    let render: RenderBlock

    public init(render: @escaping RenderBlock) {
        self.render = render
    }

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        return CanvasViewNode(content: self, drawBlock: self.render)
    }
}

@MainActor
fileprivate class CanvasViewNode: ViewNode {

    private(set) var drawBlock: Canvas.RenderBlock

    init<Content: View>(content: Content, drawBlock: @escaping Canvas.RenderBlock) {
        self.drawBlock = drawBlock
        super.init(content: content)
    }

    override func draw(with context: GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        self.drawBlock(context, self.frame.size)

        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }

    override func merge(_ otherNode: ViewNode) {
        guard let otherNode = otherNode as? CanvasViewNode else {
            return
        }
        
        self.drawBlock = otherNode.drawBlock
    }
}
