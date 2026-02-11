//
//  DrawingGroupModifier.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

import Math

public extension View {
    func drawingGroup() -> some View {
        self.modifier(DrawingGroupModifier(content: self))
    }
}

struct DrawingGroupModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        DrawingGroupViewNode(
            contentNode: context.makeNode(from: content),
            content: content
        )
    }
}

class DrawingGroupViewNode: ViewModifierNode {
    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.translateBy(x: frame.origin.x, y: -frame.origin.y)

        if let layer = layer {
            layer.drawLayer(in: context)
        }
        if context.environment.debugViewDrawingOptions.contains(.drawViewOverlays) {
            context.drawDebugBorders(frame.size, color: debugNodeColor)
        }
    }

    override func performLayout() {
        super.performLayout()
        invalidateLayerIfNeeded()
    }

    override func createLayer() -> UILayer? {
        let layer = UILayer(frame: self.frame) { [weak self] context, _ in
            guard let self else {
                return
            }
            self.contentNode.draw(with: context)
        }
        layer.debugLabel = "Drawing Group \(self.accessibilityIdentifier ?? "")"
        layer.propagatesInvalidation = false
        return layer
    }
}
