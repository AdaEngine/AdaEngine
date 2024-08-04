//
//  Canvas.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

import Math

/// A view type that supports immediate mode drawing.
public struct Canvas: View, ViewNodeBuilder {

    public typealias RenderBlock = (inout UIGraphicsContext, Size) -> Void

    public typealias Body = Never
    public var body: Never { fatalError() }

    let render: RenderBlock

    public init(render: @escaping RenderBlock) {
        self.render = render
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        return CanvasViewNode(content: self, drawBlock: self.render)
    }
}

@MainActor
class CanvasViewNode: ViewNode {

    private(set) var drawBlock: Canvas.RenderBlock

    init<Content: View>(content: Content, drawBlock: @escaping Canvas.RenderBlock) {
        self.drawBlock = drawBlock
        super.init(content: content)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = self.environment
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        self.drawBlock(&context, self.frame.size)

        super.draw(with: context)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let otherNode = newNode as? CanvasViewNode else {
            return
        }
        
        self.drawBlock = otherNode.drawBlock
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }
}
