//
//  DrawingGroupModifier.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

public extension View {
    func drawingGroup() -> some View {
        self.modifier(DrawingGroupModifier(content: self))
    }
}

struct DrawingGroupModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        DrawingGroupViewNode(contentNode: context.makeNode(from: content), content: content)
    }
}

class DrawingGroupViewNode: ViewModifierNode {
    override func draw(with context: UIGraphicsContext) {
        if let layer = layer {
            var context = context
            context.translateBy(x: frame.origin.x, y: -frame.origin.y)
            layer.drawLayer(in: context)
        }
    }

    override func performLayout() {
        super.performLayout()
        invalidateLayerIfNeeded()
    }

    override func createLayer() -> UILayer? {
        let layer = UILayer(frame: self.frame) { [weak self] context, size in
            guard let self else {
                return
            }
            
            var context = context
//            context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
            self.contentNode.draw(with: context)
        }
        layer.debugLabel = "Drawing Group"
        return layer
    }
}
