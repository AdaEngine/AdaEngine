//
//  OpacityModifier.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

public extension View {
    func opacity(_ opacity: Float) -> some View {
        modifier(_OpacityView(opacity: opacity, content: self))
    }
}

struct _OpacityView<Content: View>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never

    let opacity: Float
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = OpacityViewNodeModifier(contentNode: context.makeNode(from: content), content: content)
        node.opacity = opacity
        return node
    }
}

final class OpacityViewNodeModifier: ViewModifierNode {
    var opacity: Float = 1

    override func draw(with context: UIGraphicsContext) {
        if let layer = layer {
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
            context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
            context.opacity = self.opacity
            self.contentNode.draw(with: context)
        }
        layer.debugLabel = "opacity"
        return layer
    }
}
